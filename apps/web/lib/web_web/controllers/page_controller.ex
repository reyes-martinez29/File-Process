defmodule WebWeb.PageController do
  use WebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def upload(conn, %{"archivos" => archivos}) when is_list(archivos) do
    # Process all uploaded files
    # Phoenix uploads don't preserve extensions, so we create temp files with proper names

    # Step 1: Create temporary files with correct extensions
    temp_files =
      Enum.map(archivos, fn archivo ->
        temp_path = System.tmp_dir!() <> "/" <> archivo.filename
        File.cp!(archivo.path, temp_path)
        temp_path
      end)

    # Step 2: Process all files with FProcess
    resultado = FProcess.process_files(temp_files)

    # Step 3: Clean up all temporary files
    Enum.each(temp_files, &File.rm/1)

    # Step 4: Show results
    case resultado do
      {:ok, reporte} ->
        message = build_success_message(reporte, length(archivos))
        conn
        |> put_flash(:info, message)
        |> redirect(to: ~p"/")

      {:error, razon} ->
        conn
        |> put_flash(:error, "Error: #{razon}")
        |> redirect(to: ~p"/")
    end
  end

  def upload(conn, _params) do
    conn
    |> put_flash(:error, "No files received")
    |> redirect(to: ~p"/")
  end

  # Private helper functions

  defp build_success_message(reporte, total_files) do
    "Successfully processed #{reporte.success_count} of #{total_files} file(s). " <>
    "Check output/reporte_output.txt for details."
  end
end
