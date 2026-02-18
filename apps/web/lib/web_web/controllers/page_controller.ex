defmodule WebWeb.PageController do
  use WebWeb, :controller

  # File size limits (security/DoS prevention)
  @max_file_size_mb 50
  @max_total_size_mb 100
  @max_file_size_bytes @max_file_size_mb * 1024 * 1024
  @max_total_size_bytes @max_total_size_mb * 1024 * 1024

  def home(conn, _params) do
    # Render home page with optional report data from assigns
    render(conn, :home, report: nil)
  end

  def benchmark_results(conn, %{"archivos" => archivos}) when is_list(archivos) do
    # Step 1: Create temporary files with UNIQUE names to avoid OS caching issues
    # Using timestamp + random suffix ensures each benchmark run uses fresh files
    timestamp = System.system_time(:millisecond)

    temp_files =
      Enum.with_index(archivos, fn archivo, idx ->
        # Create unique filename: timestamp_index_originalname
        unique_name = "#{timestamp}_#{idx}_#{archivo.filename}"
        temp_path = Path.join(System.tmp_dir!(), unique_name)
        File.cp!(archivo.path, temp_path)
        temp_path
      end)

    # Step 2: Build processing options for benchmark mode
    opts = [benchmark: true, verbose: false]

    # Step 3: Process files using FProcess.process_files with benchmark mode
    # This is the CORRECT way - same as CLI uses
    resultado = FProcess.process_files(temp_files, opts)

    # Step 4: Clean up temporary files
    Enum.each(temp_files, &File.rm/1)

    # Step 5: Render benchmark results
    case resultado do
      {:ok, reporte} ->
        # Extract benchmark_data from the execution report
        benchmark_data = reporte.benchmark_data

        render(conn, :benchmark, data: benchmark_data)

      {:error, razon} ->
        conn
        |> put_flash(:error, "Benchmark error: #{razon}")
        |> redirect(to: ~p"/")
    end
  end

  def upload(conn, %{"archivos" => archivos, "processing_mode" => mode} = params)
      when is_list(archivos) do
    # Security: Validate file sizes before processing (prevents DoS/OOM)
    case validate_file_sizes(archivos) do
      :ok ->
        process_upload(conn, archivos, mode, params)

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> render(:home, report: nil)
    end
  end

  # Fallback when no processing mode is specified (defaults to parallel)
  def upload(conn, %{"archivos" => archivos}) when is_list(archivos) do
    upload(conn, %{"archivos" => archivos, "processing_mode" => "parallel"})
  end

  def upload(conn, _params) do
    conn
    |> put_flash(:error, "No files received")
    |> render(:home, report: nil)
  end

  # Actual processing logic (separated for cleaner validation flow)
  defp process_upload(conn, archivos, mode, params) do
    # Process all uploaded files
    # Phoenix uploads don't preserve extensions, so we create temp files with proper names

    # Step 1: Create temporary files with correct extensions
    temp_files =
      Enum.map(archivos, fn archivo ->
        temp_path = System.tmp_dir!() <> "/" <> archivo.filename
        File.cp!(archivo.path, temp_path)
        temp_path
      end)

    # Step 2: Build processing options based on selected mode and advanced config
    opts = build_processing_options(mode, params)

    # Step 3: Process all files with FProcess using selected mode
    resultado = FProcess.process_files(temp_files, opts)

    # Step 4: Clean up all temporary files
    Enum.each(temp_files, &File.rm/1)

    # Step 5: Store report in ETS and save only ID in session (avoids cookie overflow)
    case resultado do
      {:ok, reporte} ->
        # Generate unique ID and store report in ETS with automatic cleanup
        report_id = generate_report_id()
        Web.ReportStore.put(report_id, reporte)

        conn
        |> put_session(:report_id, report_id)
        |> put_flash(:info, build_success_message(reporte, length(archivos)))
        |> render(:results, report: reporte)

      {:error, razon} ->
        conn
        |> put_flash(:error, "Error: #{razon}")
        |> render(:home, report: nil)
    end
  end

  def results(conn, _params) do
    # Get report ID from session and retrieve report from ETS
    case get_session(conn, :report_id) do
      nil ->
        conn
        |> put_flash(:error, "No processing report found. Please upload files first.")
        |> redirect(to: ~p"/")

      report_id ->
        case Web.ReportStore.get(report_id) do
          {:ok, report} ->
            render(conn, :results, report: report)

          :error ->
            conn
            |> put_flash(:error, "Report expired or not found. Please process files again.")
            |> redirect(to: ~p"/")
        end
    end
  end

  def errors(conn, _params) do
    # Get report ID from session and retrieve report from ETS
    case get_session(conn, :report_id) do
      nil ->
        conn
        |> put_flash(:error, "No processing report found. Please upload files first.")
        |> redirect(to: ~p"/")

      report_id ->
        case Web.ReportStore.get(report_id) do
          {:ok, report} ->
            render(conn, :errors, report: report)

          :error ->
            conn
            |> put_flash(:error, "Report expired or not found. Please process files again.")
            |> redirect(to: ~p"/")
        end
    end
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  # Build processing options based on mode and additional parameters.
  #
  # For parallel mode, extracts and validates max_workers and timeout configuration.
  # Applies safe default values and boundaries to prevent resource exhaustion.
  defp build_processing_options(mode, params) when is_map(params) do
    base_opts = case mode do
      "sequential" -> [mode: :sequential]
      "parallel" -> [mode: :parallel]
      "benchmark" -> [benchmark: true]
      _ -> [mode: :parallel]  # Default to parallel if unknown
    end

    # Add advanced configuration for parallel mode
    if mode == "parallel" do
      base_opts
      |> maybe_add_max_workers(params)
      |> maybe_add_timeout(params)
    else
      base_opts
    end
  end

  # Extract and validate max_workers parameter.
  #
  # Ensures the value is within safe boundaries:
  # - Minimum: 1 worker
  # - Maximum: System.schedulers_online() * 2 (prevents VM saturation)
  # - Default: 8 workers
  #
  # Using more workers than CPU cores * 2 can degrade performance due to
  # excessive context switching and resource contention.
  defp maybe_add_max_workers(opts, params) do
    case Map.get(params, "max_workers") do
      nil ->
        opts

      value when is_binary(value) ->
        max_allowed = System.schedulers_online() * 2
        workers = validate_integer(value, min: 1, max: max_allowed, default: 8)
        Keyword.put(opts, :max_workers, workers)

      _ ->
        opts
    end
  end

  # Extract and validate timeout parameter.
  #
  # Ensures the value is within safe boundaries:
  # - Minimum: 1000ms (1 second) - prevents premature timeouts
  # - Maximum: 60000ms (60 seconds) - prevents indefinite blocking
  # - Default: 30000ms (30 seconds)
  #
  # Timeouts that are too low cause false failures, while timeouts that are
  # too high can block the web request and degrade user experience.
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

  # Validate and clamp an integer value within boundaries.
  #
  # Parameters:
  # - value: String representation of integer
  # - min: Minimum allowed value
  # - max: Maximum allowed value
  # - default: Default value if parsing fails
  #
  # Returns: Validated integer clamped between min and max
  defp validate_integer(value, opts) do
    min = Keyword.fetch!(opts, :min)
    max = Keyword.fetch!(opts, :max)
    default = Keyword.fetch!(opts, :default)

    case Integer.parse(value) do
      {num, _} when num >= min and num <= max ->
        num

      {num, _} when num < min ->
        min

      {num, _} when num > max ->
        max

      :error ->
        default
    end
  end

  # Validate file sizes to prevent DoS attacks and OOM conditions.
  #
  # Returns :ok if all files are within limits, or {:error, message} otherwise.
  defp validate_file_sizes(archivos) do
    # Get file sizes
    file_sizes = Enum.map(archivos, fn archivo ->
      case File.stat(archivo.path) do
        {:ok, %{size: size}} -> {archivo.filename, size}
        {:error, _} -> {archivo.filename, 0}
      end
    end)

    total_size = Enum.reduce(file_sizes, 0, fn {_name, size}, acc -> acc + size end)

    # Check individual file sizes
    oversized_files =
      Enum.filter(file_sizes, fn {_name, size} ->
        size > @max_file_size_bytes
      end)

    cond do
      oversized_files != [] ->
        [{filename, size} | _] = oversized_files
        size_mb = Float.round(size / (1024 * 1024), 2)
        {:error, "File '#{filename}' is too large (#{size_mb} MB). Maximum file size is #{@max_file_size_mb} MB."}

      total_size > @max_total_size_bytes ->
        total_mb = Float.round(total_size / (1024 * 1024), 2)
        {:error, "Total upload size (#{total_mb} MB) exceeds maximum allowed (#{@max_total_size_mb} MB). Please upload fewer or smaller files."}

      true ->
        :ok
    end
  end

  # Build success message for flash notification.
  defp build_success_message(reporte, total_files) do
    "Successfully processed #{reporte.success_count} of #{total_files} file(s)."
  end

  # Generate unique report ID for ETS storage.
  #
  # Uses cryptographically strong random bytes to ensure uniqueness.
  # The ID is URL-safe and keeps the session cookie small (~22 bytes).
  defp generate_report_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
