defmodule WebWeb.ErrorsLive do
  @moduledoc """
  LiveView for displaying only files with errors from processing report.
  Filters results to show only :error and :partial status files.
  """
  use WebWeb, :live_view
  import WebWeb.SharedHelpers
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Errors")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    report_id = params["id"]

    case Web.ReportStore.get(report_id) do
      {:ok, report} ->
        # Filter only files with errors or partial status
        errors =
          report.results
          |> Enum.filter(&(&1.status in [:error, :partial]))

        socket =
          socket
          |> assign(:report, report)
          |> assign(:report_id, report_id)
          |> assign(:errors, errors)
          |> assign(:total_errors, length(errors))

        {:noreply, socket}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Report not found or expired")
         |> push_navigate(to: ~p"/")}
    end
  end
end
