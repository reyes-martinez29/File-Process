defmodule FProcess.Metrics.LogMetrics do
  @moduledoc """
  Calculates metrics for system log files.

  Metrics extracted:
  - Distribution by log level (DEBUG, INFO, WARN, ERROR, FATAL)
  - Most frequent errors
  - Components with most errors
  - Temporal distribution (logs per hour)
  - Time between critical errors
  - Recurring error patterns
  """

  alias FProcess.Structs.LogEntry

  @doc """
  Calculate all metrics from a list of LogEntry structs.

  Returns:
  - `{:ok, metrics_map}` - Metrics calculated successfully
  - `{:error, reason}` - Calculation failed
  """
  @spec calculate(list(LogEntry.t())) :: {:ok, map()} | {:error, String.t()}
  def calculate([]), do: {:error, "No log entries to analyze"}

  def calculate(entries) when is_list(entries) do
    metrics = %{
      total_entries: length(entries),
      level_distribution: calculate_level_distribution(entries),
      most_frequent_errors: find_most_frequent_errors(entries, 5),
      top_error_components: find_top_error_components(entries, 5),
      hourly_distribution: calculate_hourly_distribution(entries),
      critical_errors_count: count_critical_errors(entries),
      error_patterns: find_error_patterns(entries, 3)
    }

    {:ok, metrics}
  end

  def calculate(_invalid) do
    {:error, "Invalid log data format"}
  end

  # ============================================================================
  # Private Functions - Level Distribution
  # ============================================================================

  defp calculate_level_distribution(entries) do
    total = length(entries)

    distribution =
      entries
      |> Enum.group_by(& &1.level)
      |> Enum.map(fn {level, level_entries} ->
        count = length(level_entries)
        percentage = if total > 0, do: Float.round(count / total * 100, 1), else: 0.0

        {level, %{count: count, percentage: percentage}}
      end)
      |> Enum.into(%{})

    # Ensure all levels are present
    ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]
    |> Enum.map(fn level ->
      {level, Map.get(distribution, level, %{count: 0, percentage: 0.0})}
    end)
    |> Enum.into(%{})
  end

  # ============================================================================
  # Private Functions - Error Analysis
  # ============================================================================

  defp find_most_frequent_errors(entries, top_n) do
    entries
    |> Enum.filter(fn entry -> entry.level in ["ERROR", "FATAL"] end)
    |> Enum.map(& &1.message)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_msg, count} -> count end, :desc)
    |> Enum.take(top_n)
    |> Enum.map(fn {message, count} ->
      %{
        message: String.slice(message, 0..100),  # Truncate long messages
        count: count
      }
    end)
  end

  defp find_top_error_components(entries, top_n) do
    entries
    |> Enum.filter(fn entry -> entry.level in ["ERROR", "FATAL"] end)
    |> Enum.group_by(& &1.component)
    |> Enum.map(fn {component, component_entries} ->
      {component, length(component_entries)}
    end)
    |> Enum.sort_by(fn {_component, count} -> count end, :desc)
    |> Enum.take(top_n)
    |> Enum.map(fn {component, count} ->
      %{component: component, error_count: count}
    end)
  end

  defp count_critical_errors(entries) do
    Enum.count(entries, fn entry -> entry.level in ["ERROR", "FATAL"] end)
  end

  # ============================================================================
  # Private Functions - Temporal Analysis
  # ============================================================================

  defp calculate_hourly_distribution(entries) do
    entries
    |> Enum.map(& &1.hour)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {hour, _count} -> hour end)
    |> Enum.map(fn {hour, count} ->
      %{hour: hour, count: count}
    end)
  end

  # ============================================================================
  # Private Functions - Pattern Detection
  # ============================================================================

  defp find_error_patterns(entries, top_n) do
    entries
    |> Enum.filter(fn entry -> entry.level in ["ERROR", "FATAL"] end)
    |> Enum.map(&extract_error_pattern/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_pattern, count} -> count end, :desc)
    |> Enum.take(top_n)
    |> Enum.map(fn {pattern, count} ->
      %{pattern: pattern, occurrences: count}
    end)
  end

  defp extract_error_pattern(entry) do
    # Extract key words from error messages to identify patterns
    # This is a simple implementation - could be enhanced with NLP
    message = entry.message

    cond do
      String.contains?(message, "Timeout") or String.contains?(message, "timeout") ->
        "Timeout errors"

      String.contains?(message, "Connection") or String.contains?(message, "conexión") ->
        "Connection errors"

      String.contains?(message, "Deadlock") or String.contains?(message, "deadlock") ->
        "Database deadlock"

      String.contains?(message, "NullPointer") or String.contains?(message, "null") ->
        "Null pointer errors"

      String.contains?(message, "Permission") or String.contains?(message, "permiso") ->
        "Permission errors"

      true ->
        # Generic pattern based on component
        "#{entry.component} errors"
    end
  end
end
