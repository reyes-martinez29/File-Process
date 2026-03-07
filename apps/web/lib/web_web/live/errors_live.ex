defmodule WebWeb.ErrorsLive do
  @moduledoc """
  LiveView for displaying only files with errors from processing report.
  Filters results to show only :error and :partial status files.
  """
  use WebWeb, :live_view
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

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms), do: "#{Float.round(ms / 1000, 2)}s"

  defp format_error({line, msg}), do: "Line #{line}: #{msg}"
  defp format_error(msg) when is_binary(msg), do: msg
  defp format_error(other), do: inspect(other)
end
