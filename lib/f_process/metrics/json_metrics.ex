defmodule FProcess.Metrics.JSONMetrics do
  @moduledoc """
  Calculates metrics for JSON user and session data.

  Metrics extracted:
  - Total registered users
  - Active vs inactive users
  - Average session duration
  - Total pages visited
  - Top 5 most common actions
  - Peak activity hour
  """

  @doc """
  Calculate all metrics from parsed JSON data.

  Expects data in the format:
  %{users: [%User{}, ...], sessions: [%Session{}, ...]}

  Returns:
  - `{:ok, metrics_map}` - Metrics calculated successfully
  - `{:error, reason}` - Calculation failed
  """
  @spec calculate(map()) :: {:ok, map()} | {:error, String.t()}
  def calculate(%{users: users, sessions: sessions}) when is_list(users) and is_list(sessions) do
    metrics = %{
      total_users: length(users),
      active_users: count_active_users(users),
      inactive_users: count_inactive_users(users),
      active_percentage: calculate_active_percentage(users),
      total_sessions: length(sessions),
      avg_session_duration: calculate_avg_session_duration(sessions),
      total_pages_visited: calculate_total_pages(sessions),
      top_actions: find_top_actions(sessions, 5),
      peak_hour: find_peak_hour(sessions)
    }

    {:ok, metrics}
  end

  def calculate(_invalid) do
    {:error, "Invalid JSON data format. Expected users and sessions lists"}
  end

  # ============================================================================
  # Private Functions - User Metrics
  # ============================================================================

  defp count_active_users(users) do
    Enum.count(users, fn user -> user.active == true end)
  end

  defp count_inactive_users(users) do
    Enum.count(users, fn user -> user.active == false end)
  end

  defp calculate_active_percentage(users) do
    total = length(users)

    if total > 0 do
      active = count_active_users(users)
      Float.round(active / total * 100, 1)
    else
      0.0
    end
  end

  # ============================================================================
  # Private Functions - Session Metrics
  # ============================================================================

  defp calculate_avg_session_duration(sessions) do
    durations =
      sessions
      |> Enum.map(& &1.duration_seconds)
      |> Enum.reject(&is_nil/1)

    case durations do
      [] ->
        0

      durations ->
        total = Enum.sum(durations)
        round(total / length(durations))
    end
  end

  defp calculate_total_pages(sessions) do
    sessions
    |> Enum.map(& &1.pages_visited)
    |> Enum.reject(&is_nil/1)
    |> Enum.sum()
  end

  defp find_top_actions(sessions, top_n) do
    sessions
    |> Enum.flat_map(fn session -> session.actions || [] end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_action, count} -> count end, :desc)
    |> Enum.take(top_n)
    |> Enum.map(fn {action, count} -> %{action: action, count: count} end)
  end

  defp find_peak_hour(sessions) do
    sessions
    |> Enum.map(&extract_hour_from_session/1)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] ->
        nil

      hours ->
        hours
        |> Enum.frequencies()
        |> Enum.max_by(fn {_hour, count} -> count end, fn -> {0, 0} end)
        |> case do
          {hour, count} -> %{hour: hour, session_count: count}
        end
    end
  end

  defp extract_hour_from_session(session) do
    case session.start do
      nil ->
        nil

      timestamp when is_binary(timestamp) ->
        # Parse ISO-8601 timestamp to extract hour
        # Format: "2024-02-29T10:00:00Z"
        case Regex.run(~r/T(\d{2}):/, timestamp) do
          [_, hour_str] ->
            case Integer.parse(hour_str) do
              {hour, _} -> hour
              _ -> nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end
end
