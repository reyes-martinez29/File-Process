defmodule WebWeb.PageController do
  use WebWeb, :controller

  def home(conn, _params) do
    IO.inspect(FProcess.Core, label: "core module")
    render(conn, :home)
  end

  def results(conn, _params) do
    # Datos de prueba para llenar las pestañas
    archivos_csv = [
      %{nombre: "ventas_enero.csv", filas: 150, total: "$24,399.93"},
      %{nombre: "ventas_febrero.csv", filas: 182, total: "$26,721.37"},
      %{nombre: "reporte_anual.csv", filas: 1205, total: "$154,200.10"}
    ]

    archivos_json = [
      %{nombre: "config_sistema.json", status: "Cargado"},
      %{nombre: "metadatos_proceso.json", status: "Procesado"}
    ]

    # Pasamos los datos al HTML mediante 'csvs' y 'jsons'
    render(conn, :results, csvs: archivos_csv, jsons: archivos_json)
  end


  def results(conn, _params) do
    render(conn, :results)
  end

  def results(conn, params) do

  IO.inspect(params, label: "Form Data")

  render(conn, :results)
end



end
