defmodule WebWeb.ResultsLive do
  @moduledoc """
  LiveView para visualizar resultados de procesamiento de archivos.
  """
  use WebWeb, :live_view
  import WebWeb.SharedHelpers
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Resultados")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    report_id = params["id"]

    case Web.ReportStore.get(report_id) do
      {:ok, report} ->
        socket =
          socket
          |> assign(:report, report)
          |> assign(:report_id, report_id)

        {:noreply, socket}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Reporte no encontrado o expirado")
         |> push_navigate(to: ~p"/")}
    end
  end
end
