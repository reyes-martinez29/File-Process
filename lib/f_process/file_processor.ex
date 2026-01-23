defmodule FProcess.FileProcessor do
  @moduledoc """
  The core worker that processes a single file.

  This module is the heart of the file processing logic. It:
  1. Receives a {type, path} tuple
  2. Delegates to the appropriate parser
  3. Validates the parsed data
  4. Calculates metrics using the metrics module
  5. Returns a FileResult struct

  This module is reused by both Sequential and Parallel modes,
  ensuring consistent processing logic across all execution modes.
  """

  alias FProcess.Structs.FileResult
  alias FProcess.Parsers.{CSVParser, JSONParser, LogParser, XMLParser}
  alias FProcess.Metrics.{CSVMetrics, JSONMetrics, LogMetrics, XMLMetrics}

  @type file_input :: {FProcess.FileDiscovery.file_type(), String.t()}
  @type processing_result :: FileResult.t()

  @doc """
  Process a single file end-to-end.

  This is the main entry point for file processing. It orchestrates
  the complete pipeline: parse -> validate -> calculate metrics.

  ## Parameters

  - `file_input` - Tuple of {type, path}, e.g., {:csv, "data/file.csv"}
  - `config` - Configuration map with timeout, retries, etc.

  ## Returns

  A `FileResult` struct with status :ok, :error, or :partial
  """
  @spec process(file_input(), map()) :: processing_result()
  def process({type, path}, _config \\ %{}) do
    start_time = System.monotonic_time(:millisecond)

    # Create initial result struct
    result = FileResult.new(path, type)

    # Execute processing with error handling
    final_result =
      result
      |> parse_file(type, path)
      |> calculate_metrics(type)
      |> finalize_result(start_time)

    final_result
  end

  # ============================================================================
  # Private Functions - Processing Pipeline
  # ============================================================================

  # Step 1: Parse the file based on its type
  defp parse_file(result, type, path) do
    case parse_by_type(type, path) do
      {:ok, parsed_data} ->
        # Store parsed data temporarily in the result
        Map.put(result, :parsed_data, parsed_data)

      {:error, reason} ->
        # Mark as error and stop pipeline
        FileResult.error(result, [reason])

      {:partial, parsed_data, errors} ->
        # Some data parsed, some failed
        result
        |> Map.put(:parsed_data, parsed_data)
        |> Map.put(:parse_errors, errors)
        |> Map.put(:status, :partial)
    end
  end

  # Step 2: Calculate metrics from parsed data
  defp calculate_metrics(%{status: :error} = result, _type) do
    # If parsing failed, skip metrics calculation
    result
  end

  defp calculate_metrics(result, type) do
    parsed_data = Map.get(result, :parsed_data)

    case calculate_by_type(type, parsed_data) do
      {:ok, metrics} ->
        Map.put(result, :metrics, metrics)

      {:error, reason} ->
        # Metrics calculation failed
        existing_errors = Map.get(result, :errors, [])
        FileResult.error(result, existing_errors ++ [reason])
    end
  end

  # Step 3: Finalize the result (calculate duration, clean up temp data)
  defp finalize_result(result, start_time) do
    end_time = System.monotonic_time(:millisecond)
    duration_ms = end_time - start_time

    result
    |> Map.delete(:parsed_data)  # Remove temporary parsed data
    |> Map.put(:duration_ms, duration_ms)
    |> add_line_counts()
    |> normalize_status()
  end

  # ============================================================================
  # Private Functions - Type Dispatching
  # ============================================================================

  defp parse_by_type(:csv, path), do: CSVParser.parse(path)
  defp parse_by_type(:json, path), do: JSONParser.parse(path)
  defp parse_by_type(:log, path), do: LogParser.parse(path)
  defp parse_by_type(:xml, path), do: XMLParser.parse(path)
  defp parse_by_type(unknown, _path) do
    {:error, "Unknown file type: #{unknown}"}
  end

  defp calculate_by_type(:csv, data), do: CSVMetrics.calculate(data)
  defp calculate_by_type(:json, data), do: JSONMetrics.calculate(data)
  defp calculate_by_type(:log, data), do: LogMetrics.calculate(data)
  defp calculate_by_type(:xml, data), do: XMLMetrics.calculate(data)
  defp calculate_by_type(unknown, _data) do
    {:error, "Unknown file type for metrics: #{unknown}"}
  end

  # ============================================================================
  # Private Functions - Result Helpers
  # ============================================================================

  defp add_line_counts(result) do
    # If we have parse_errors, count them
    parse_errors = Map.get(result, :parse_errors, [])
    lines_failed = length(parse_errors)

    # Estimate lines processed from metrics or parsed data
    lines_processed = estimate_lines_processed(result)

    result
    |> Map.put(:lines_failed, lines_failed)
    |> Map.put(:lines_processed, lines_processed)
    |> Map.delete(:parse_errors)
  end

  defp estimate_lines_processed(result) do
    # Try to get count from metrics
    case result.metrics do
      %{total_records: count} -> count
      %{total_entries: count} -> count
      %{total_sales: count} -> count
      _ -> 0
    end
  end

  defp normalize_status(result) do
    # Ensure status is consistent with errors and data
    cond do
      result.status == :error ->
        result

      length(result.errors) > 0 and map_size(result.metrics) > 0 ->
        %{result | status: :partial}

      length(result.errors) > 0 ->
        %{result | status: :error}

      true ->
        %{result | status: :ok}
    end
  end
end
