defmodule WebWeb.PageController do
  use WebWeb, :controller

  def home(conn, _params) do
    # Render home page with optional report data from assigns
    render(conn, :home, report: nil)
  end

# lib/web_web/controllers/page_controller.ex

def benchmark_results(conn, params) do
  # We extract "archivos" safely. If it doesn't exist, we default to an empty list.
  archivos = Map.get(params, "archivos", [])
  allowed_extensions = ~w(.csv .json .xml .log)

  # PHASE 1: PRE-PROCESSING & VALIDATION
  # We filter and prepare files only if they match the supported extensions.
  classified_files =
    archivos
    |> Enum.filter(fn archivo ->
      # Safety check: skip files that are not supported to avoid engine crashes
      ext = archivo.filename |> Path.extname() |> String.downcase()
      ext in allowed_extensions
    end)
    |> Enum.map(fn archivo ->
      # Create a temporary path for the file
      temp_path = Path.join(System.tmp_dir!(), archivo.filename)
      File.cp!(archivo.path, temp_path)

      # Map the extension to the atom type required by the processing engine
      extension = archivo.filename |> Path.extname() |> String.downcase() |> String.replace(".", "")
      type = case extension do
        "csv"  -> :csv
        "json" -> :json
        "xml"  -> :xml
        _      -> :txt
      end
      {type, temp_path}
    end)

  # FINAL CHECK: Execute benchmark only if we have valid files
  case classified_files do
    [] ->
      conn
      |> put_flash(:error, "No valid files selected. Please upload CSV, JSON, XML, or LOG.")
      |> redirect(to: ~p"/")

    files_to_process ->
      # PHASE 2: EXECUTION
      # Running the benchmark with prepared files to ensure timing accuracy
      {_results, benchmark_data} = FProcess.Modes.Benchmark.run(files_to_process, %{show_progress: false})

      # PHASE 3: CLEANUP
      # Remove temporary files after processing is complete
      Enum.each(files_to_process, fn {_, path} -> File.rm(path) end)

      render(conn, :benchmark, data: benchmark_data)
end


  # PHASE 2: EXECUTION (Clean call)
  # Invoking the Benchmark mode directly. At this point, files are already
  # on disk, mimicking the environment of a console-based execution.
  {_results, benchmark_data} = FProcess.Modes.Benchmark.run(classified_files, %{show_progress: false})

  # PHASE 3: CLEANUP
  # Removing temporary files to free up system resources
  Enum.each(classified_files, fn {_, path} -> File.rm(path) end)

  # PHASE 4: RENDERING
  # Passing the clean benchmark data to the view
  render(conn, :benchmark, data: benchmark_data)
end
  def upload(conn, %{"archivos" => archivos, "processing_mode" => mode})
      when is_list(archivos) do
    # Process all uploaded files
    # Phoenix uploads don't preserve extensions, so we create temp files with proper names

    # Step 1: Create temporary files with correct extensions
    temp_files =
      Enum.map(archivos, fn archivo ->
        temp_path = System.tmp_dir!() <> "/" <> archivo.filename
        File.cp!(archivo.path, temp_path)
        temp_path
      end)

    # Step 2: Build processing options based on selected mode
    opts = build_processing_options(mode)

    # Step 3: Process all files with FProcess using selected mode
    resultado = FProcess.process_files(temp_files, opts)

    # Step 4: Clean up all temporary files
    Enum.each(temp_files, &File.rm/1)

    # Step 5: Store report in ETS and save only ID in session (avoids cookie overflow)
    case resultado do
      {:ok, reporte} ->
        # Generate unique ID and store report in ETS
        report_id = generate_report_id()
        :ets.insert(:reports_store, {report_id, reporte, System.system_time(:second)})

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

  # Fallback when no processing mode is specified (defaults to parallel)
  def upload(conn, %{"archivos" => archivos}) when is_list(archivos) do
    upload(conn, %{"archivos" => archivos, "processing_mode" => "parallel"})
  end

  def upload(conn, _params) do
    conn
    |> put_flash(:error, "No files received")
    |> render(:home, report: nil)
  end

  def results(conn, _params) do
    # Get report ID from session and retrieve report from ETS
    case get_session(conn, :report_id) do
      nil ->
        conn
        |> put_flash(:error, "No processing report found. Please upload files first.")
        |> redirect(to: ~p"/")

      report_id ->
        case :ets.lookup(:reports_store, report_id) do
          [{^report_id, report, _timestamp}] ->
            render(conn, :results, report: report)

          [] ->
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
        case :ets.lookup(:reports_store, report_id) do
          [{^report_id, report, _timestamp}] ->
            render(conn, :errors, report: report)

          [] ->
            conn
            |> put_flash(:error, "Report expired or not found. Please process files again.")
            |> redirect(to: ~p"/")
        end
    end
  end

  # Private helper functions

  defp build_processing_options(mode) do
    case mode do
      "sequential" -> [mode: :sequential]
      "parallel" -> [mode: :parallel]
      "benchmark" -> [benchmark: true]
      _ -> [mode: :parallel]  # Default to parallel if unknown
    end
  end

  defp build_success_message(reporte, total_files) do
    "Successfully processed #{reporte.success_count} of #{total_files} file(s)."
  end

  defp generate_report_id do
    # Generate unique ID using random bytes (keeps session cookie small)
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
