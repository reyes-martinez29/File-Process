defmodule WebWeb.PageController do
  use WebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def upload(conn, %{"archivos" => archivos}) when is_list(archivos) do
    # Currently processing only the first uploaded file
    archivo = List.first(archivos)

    # Create a temporary file with the correct extension
    # Phoenix uploads don't preserve extensions, but FProcess needs them
    temp_path = System.tmp_dir!() <> "/" <> archivo.filename

    # Copy uploaded file to temp location with proper extension
    File.cp!(archivo.path, temp_path)

    # Process the file with FProcess
    resultado = FProcess.process_file(temp_path)

    # Clean up temporary file
    File.rm(temp_path)

    case resultado do
      {:ok, _reporte} ->
        conn
        |> put_flash(:info, "File processed successfully: #{archivo.filename}")
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
end
