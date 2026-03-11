defmodule WebWeb.PageLive do
  use WebWeb, :live_view
  embed_templates "page_live/*"
  require Logger

  # File size limits (security/DoS prevention)
  @max_file_size_mb 50
  @max_total_size_mb 100
  @max_file_size_bytes @max_file_size_mb * 1024 * 1024
  @max_total_size_bytes @max_total_size_mb * 1024 * 1024

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:processing, false)
      |> assign(:processing_mode, "sequential")
      |> assign(:show_advanced, false)
      |> allow_upload(:archivos,
        accept: ~w(.csv .json .xml .log),
        max_entries: 50,
        max_file_size: @max_file_size_bytes
      )

    {:ok, socket}
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    socket =
      socket
      |> assign(:processing_mode, mode)
      |> assign(:show_advanced, false)

    {:noreply, socket}
  end

  def handle_event("toggle_advanced", _params, socket) do
    {:noreply, assign(socket, :show_advanced, !socket.assigns.show_advanced)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :archivos, ref)}
  end

  def handle_event("process_files", params, socket) do
    mode    = socket.assigns.processing_mode
    entries = socket.assigns.uploads.archivos.entries

    if entries == [] do
      {:noreply, put_flash(socket, :error, "Primero tienes que seleccionar al menos 1 archivo.")}
    else
      socket    = assign(socket, :processing, true)
      timestamp = System.system_time(:millisecond)

      temp_files =
        consume_uploaded_entries(socket, :archivos, fn %{path: path}, entry ->
          unique_name = "#{timestamp}_#{entry.client_name}"
          temp_path   = Path.join(System.tmp_dir!(), unique_name)
          File.cp!(path, temp_path)
          {:ok, temp_path}
        end)

      case validate_total_size(temp_files) do
        {:error, reason} ->
          Enum.each(temp_files, &File.rm/1)
          {:noreply, socket |> assign(:processing, false) |> put_flash(:error, reason)}

        :ok ->
          request_id = generate_request_id()
          Logger.metadata(request_id: request_id, file_count: length(temp_files))
          Logger.info("LiveView file processing started", mode: mode)

          opts       = build_processing_options(mode, params)
          start_time = System.monotonic_time(:millisecond)
          resultado  = FProcess.process_files(temp_files, opts)
          duration_ms = System.monotonic_time(:millisecond) - start_time

          Enum.each(temp_files, &File.rm/1)

          case resultado do
            {:ok, reporte} ->
              Logger.info("Processing completed",
                duration_ms: duration_ms,
                success: reporte.success_count,
                errors: reporte.error_count
              )

              :telemetry.execute(
                [:web, :upload, :success],
                %{duration: duration_ms, file_count: length(temp_files)},
                %{mode: mode, request_id: request_id}
              )

              # Store report and redirect to ResultsLive
              report_id = "report_#{timestamp}_#{:rand.uniform(10000)}"
              Web.ReportStore.put(report_id, reporte)

              socket =
                socket
                |> assign(:processing, false)
                |> push_navigate(to: ~p"/live/results?id=#{report_id}")

              {:noreply, socket}

            {:error, razon} ->
              Logger.error("Processing failed", duration_ms: duration_ms, reason: razon)

              :telemetry.execute(
                [:web, :upload, :error],
                %{duration: duration_ms},
                %{reason: razon, request_id: request_id}
              )

              {:noreply, socket |> assign(:processing, false) |> put_flash(:error, "Error: #{razon}")}
          end
      end
    end
  end

  def handle_event("process_benchmark", _params, socket) do
    entries = socket.assigns.uploads.archivos.entries

    if entries == [] do
      {:noreply, put_flash(socket, :error, "Primero tienes que seleccionar al menos 1 archivo.")}
    else
      socket    = assign(socket, :processing, true)
      timestamp = System.system_time(:millisecond)
      benchmark_id = "bench_#{timestamp}_#{:rand.uniform(10000)}"

      # Copy uploaded files to temporary files and store info
      temp_files =
        consume_uploaded_entries(socket, :archivos, fn %{path: path}, entry ->
          unique_name = "#{timestamp}_#{System.unique_integer([:positive])}_#{entry.client_name}"
          temp_path   = Path.join(System.tmp_dir!(), unique_name)
          File.cp!(path, temp_path)

          file_info = %{
            "path" => temp_path,
            "filename" => entry.client_name,
            "content_type" => entry.client_type
          }

          {:ok, file_info}
        end)

      # Store files info in BenchmarkStore for LiveView to access
      Web.BenchmarkStore.put(benchmark_id, temp_files)

      # Redirect to BenchmarkLive
      socket =
        socket
        |> assign(:processing, false)
        |> push_navigate(to: ~p"/live/benchmark?id=#{benchmark_id}")

      {:noreply, socket}
    end
  end

  # ============================================================================
  # Render
  # ============================================================================

  @impl true
  def render(assigns) do
    home_live(assigns)
  end

  # ============================================================================
  # Helper Components
  # ============================================================================

  # Traduce los átomos de error de Phoenix LiveView uploads a mensajes legibles
  defp upload_error_message(:too_large),      do: "El archivo supera el tamaño máximo permitido (#{@max_file_size_mb} MB)."
  defp upload_error_message(:too_many_files), do: "Se superó el número máximo de archivos (50)."
  defp upload_error_message(:not_accepted),   do: "Formato no permitido. Solo CSV, JSON, XML y LOG."
  defp upload_error_message(_),               do: "Error desconocido al subir el archivo."

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp build_processing_options(mode, params) when is_map(params) do
    base_opts =
      case mode do
        "sequential" -> [mode: :sequential]
        "parallel"   -> [mode: :parallel]
        _            -> [mode: :parallel]
      end

    if mode == "parallel" do
      base_opts
      |> maybe_add_max_workers(params)
      |> maybe_add_timeout(params)
    else
      base_opts
    end
  end

  defp maybe_add_max_workers(opts, params) do
    case Map.get(params, "max_workers") do
      nil ->
        opts

      value when is_binary(value) ->
        max_allowed = System.schedulers_online() * 2
        workers     = validate_integer(value, min: 1, max: max_allowed, default: 8)
        Keyword.put(opts, :max_workers, workers)

      _ ->
        opts
    end
  end

  defp maybe_add_timeout(opts, params) do
    case Map.get(params, "timeout") do
      nil ->
        opts

      value when is_binary(value) ->
        timeout = validate_integer(value, min: 1_000, max: 60_000, default: 30_000)
        Keyword.put(opts, :timeout, timeout)

      _ ->
        opts
    end
  end

  defp validate_integer(value, opts) do
    min     = Keyword.fetch!(opts, :min)
    max     = Keyword.fetch!(opts, :max)
    default = Keyword.fetch!(opts, :default)

    case Integer.parse(value) do
      {num, _} when num >= min and num <= max -> num
      {num, _} when num < min                -> min
      {num, _} when num > max                -> max
      :error                                 -> default
    end
  end

  defp validate_total_size(paths) do
    sizes =
      Enum.map(paths, fn path ->
        case File.stat(path) do
          {:ok, %{size: size}} -> size
          {:error, _}          -> 0
        end
      end)

    total = Enum.sum(sizes)

    if total > @max_total_size_bytes do
      total_mb = Float.round(total / (1024 * 1024), 2)
      {:error, "Tamaño total (#{total_mb} MB) supera el máximo permitido (#{@max_total_size_mb} MB)."}
    else
      :ok
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
