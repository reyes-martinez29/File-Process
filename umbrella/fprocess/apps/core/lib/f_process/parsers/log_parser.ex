defmodule FProcess.Parsers.LogParser do
  @moduledoc """
  Parser for system log files.

  Expected format:
  YYYY-MM-DD HH:MM:SS [NIVEL] [COMPONENTE] Mensaje de log

  Supported levels: DEBUG, INFO, WARN, ERROR, FATAL

  Extracts:
  - Timestamp
  - Log level
  - Component name
  - Message
  - Hour (for temporal distribution analysis)
  """

  alias FProcess.Structs.LogEntry

  @log_pattern ~r/^(\d{4}-\d{2}-\d{2})\s+(\d{2}):(\d{2}):(\d{2})\s+\[(\w+)\]\s+\[([^\]]+)\]\s+(.+)$/
  @valid_levels ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]

  @doc """
  Parse a log file and return a list of LogEntry structs.

  Returns:
  - `{:ok, log_entries}` - All lines parsed successfully
  - `{:partial, log_entries, errors}` - Some lines failed to parse
  - `{:error, reason}` - File could not be read
  """
  @spec parse(String.t()) ::
    {:ok, list(LogEntry.t())} |
    {:partial, list(LogEntry.t()), list({integer(), String.t()})} |
    {:error, String.t()}
  def parse(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        parse_content(content)

      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  # ============================================================================
  # Private Functions - Parsing
  # ============================================================================

  defp parse_content(content) do
    lines = String.split(content, "\n", trim: true)

    case lines do
      [] ->
        {:error, "Empty log file"}

      lines ->
        parse_log_lines(lines)
    end
  end

  defp parse_log_lines(lines) do
    {entries, errors} =
      lines
      |> Enum.with_index(1)
      |> Enum.reduce({[], []}, fn {line, line_num}, {entries_acc, errors_acc} ->
        case parse_log_line(line, line_num) do
          {:ok, entry} ->
            {[entry | entries_acc], errors_acc}

          {:error, reason} ->
            {entries_acc, [{line_num, reason} | errors_acc]}
        end
      end)

    # Reverse to maintain original order
    entries = Enum.reverse(entries)
    errors = Enum.reverse(errors)

    cond do
      length(entries) == 0 and length(errors) > 0 ->
        {:error, "No valid log entries found. First error: #{elem(hd(errors), 1)}"}

      length(errors) > 0 ->
        {:partial, entries, errors}

      true ->
        {:ok, entries}
    end
  end

  defp parse_log_line(line, _line_num) do
    case Regex.run(@log_pattern, line) do
      [_full, date, hour, minute, second, level, component, message] ->
        build_log_entry(date, hour, minute, second, level, component, message)

      nil ->
        {:error, "Line does not match expected log format"}
    end
  end

  # ============================================================================
  # Private Functions - Entry Construction
  # ============================================================================

  defp build_log_entry(date, hour, minute, second, level, component, message) do
    with :ok <- validate_level(level),
         {:ok, hour_int} <- parse_hour(hour) do

      timestamp = "#{date} #{hour}:#{minute}:#{second}"

      entry = %LogEntry{
        timestamp: timestamp,
        level: level,
        component: String.trim(component),
        message: String.trim(message),
        hour: hour_int
      }

      {:ok, entry}
    end
  end

  defp validate_level(level) do
    if level in @valid_levels do
      :ok
    else
      {:error, "Invalid log level '#{level}'. Valid levels: #{Enum.join(@valid_levels, ", ")}"}
    end
  end

  defp parse_hour(hour_str) do
    case Integer.parse(hour_str) do
      {hour, ""} when hour >= 0 and hour <= 23 ->
        {:ok, hour}

      _ ->
        {:error, "Invalid hour: #{hour_str}"}
    end
  end
end
