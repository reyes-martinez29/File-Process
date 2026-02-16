defmodule WebWeb.PageController do
  use WebWeb, :controller

  def home(conn, _params) do
    # Render home page with optional report data from assigns
    render(conn, :home, report: nil)
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

    # Step 5: Render results page directly (no session needed)
    case resultado do
      {:ok, reporte} ->
        conn
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
    # Direct access to /results without processing - redirect to home
    conn
    |> put_flash(:error, "No processing report found. Please upload files first.")
    |> redirect(to: ~p"/")
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
end
