defmodule WebWeb.ResultsLive do
  @moduledoc """
  LiveView para visualizar resultados de procesamiento de archivos.
  """
  use WebWeb, :live_view
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

  # Helper functions for formatting and display

  defp status_badge_config(:ok), do: %{color: "emerald", icon: "✓", text: "Success"}
  defp status_badge_config(:error), do: %{color: "rose", icon: "✕", text: "Error"}
  defp status_badge_config(:partial), do: %{color: "amber", icon: "⚠", text: "Partial"}
  defp status_badge_config(_), do: %{color: "slate", icon: "?", text: "Unknown"}

  defp file_type_config(:csv), do: %{color: "indigo", icon: "📊", label: "CSV"}
  defp file_type_config(:json), do: %{color: "amber", icon: "📄", label: "JSON"}
  defp file_type_config(:xml), do: %{color: "green", icon: "📝", label: "XML"}
  defp file_type_config(:log), do: %{color: "purple", icon: "📋", label: "LOG"}
  defp file_type_config(_), do: %{color: "slate", icon: "❓", label: "UNKNOWN"}
end
