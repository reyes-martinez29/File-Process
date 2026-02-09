defmodule FProcess.Core do
  @moduledoc """
  Core orchestrator that coordinates the file processing pipeline.

  This module is the "brain" of the system. It:
  1. Receives normalized file list from FileDiscovery
  2. Selects and delegates to the appropriate processing mode
  3. Collects results from the mode
  4. Builds the execution report
  5. Generates and saves the final report
  """

  alias FProcess.Modes.{Sequential, Parallel, Benchmark}
  alias FProcess.Report
  alias FProcess.Utils.Config
  alias FProcess.Structs.{ExecutionReport, FileResult}
  require Logger

  @type classified_files :: list({FProcess.FileDiscovery.file_type(), String.t()})
  @type processing_result :: {:ok, ExecutionReport.t()} | {:error, String.t()}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Process files using specified mode or run benchmark.
  """
  @spec process(classified_files(), keyword()) :: processing_result()
  def process(classified_files, opts \\ [])

  def process([], _opts) do
    {:error, "No files to process"}
  end

  def process(classified_files, opts) when is_list(classified_files) do
    config = Config.get(opts)
    mode = Keyword.get(opts, :mode, :parallel)
    is_benchmark = Keyword.get(opts, :benchmark, false)

    ensure_output_directory!(config.output_dir)

    start_time = DateTime.utc_now()

    {results, benchmark_data, duration_ms} = if is_benchmark do
      {results, bench_data} = execute_benchmark(classified_files, config)
      # Use parallel duration as the "official" time for benchmark
      duration = get_in(bench_data, [:parallel, :duration_ms]) || 0
      {results, bench_data, duration}
    else
      print_processing_header(mode, length(classified_files))

      # Measure only the execution mode (consistent with benchmark)
      start_monotonic = System.monotonic_time(:millisecond)

      results = execute_mode(mode, classified_files, config)

      end_monotonic = System.monotonic_time(:millisecond)

      duration = end_monotonic - start_monotonic

      {results, nil, duration}
    end

    # Build execution report (use :benchmark mode label when benchmarking)
    report_mode = if Keyword.get(opts, :benchmark, false), do: :benchmark, else: mode

    execution_report = build_execution_report(
      results,
      report_mode,
      start_time,
      duration_ms,
      classified_files,
      benchmark_data
    )

    # Print summary
    print_processing_summary(execution_report)

    # Generate and save report
    case Report.generate_and_save(execution_report, config.output_dir) do
      {:ok, report_path} ->
        # attach path into report for callers (CLI)
        execution_report = Map.put(execution_report, :report_path, report_path)
        print_completion_message(report_path)
        {:ok, execution_report}

      {:error, reason} ->
        Logger.warning("Failed to save report: #{reason}")
        Logger.info("Processing completed successfully but report could not be saved.")
        execution_report = Map.put(execution_report, :report_path, nil)
        {:ok, execution_report}
    end
  end

  def process(_invalid, _opts) do
    {:error, "Invalid classified_files format"}
  end

  # ============================================================================
  # Private Functions - Mode Execution
  # ============================================================================

  defp execute_mode(:sequential, classified_files, config) do
    Sequential.run(classified_files, config)
  end

  defp execute_mode(:parallel, classified_files, config) do
    Parallel.run(classified_files, config)
  end

  defp execute_mode(unknown_mode, _classified_files, _config) do
    Logger.warning("Unknown mode '#{unknown_mode}', falling back to sequential")
    []
  end

  defp execute_benchmark(classified_files, config) do
    # Benchmark returns {results, benchmark_data}
    Benchmark.run(classified_files, config)
  end

  # ============================================================================
  # Private Functions - Report Building
  # ============================================================================

  defp build_execution_report(results, mode, start_time, duration_ms, classified_files, benchmark_data) do
    directory = extract_directory(classified_files)
    type_counts = count_by_type(results)
    status_counts = count_by_status(results)

    report = %ExecutionReport{
      mode: mode_to_string(mode),
      start_time: start_time,
      directory: directory,
      total_files: length(results),
      csv_count: type_counts.csv,
      json_count: type_counts.json,
      log_count: type_counts.log,
      xml_count: type_counts.xml,
      success_count: status_counts.success,
      error_count: status_counts.error,
      partial_count: status_counts.partial,
      total_duration_ms: duration_ms,
      results: results
    }

    # Add benchmark data if available
    if benchmark_data do
      Map.put(report, :benchmark_data, benchmark_data)
    else
      report
    end
  end

  defp extract_directory([{_type, first_path} | _]) do
    Path.dirname(first_path)
  end

  defp extract_directory(_), do: "N/A"

  defp count_by_type(results) do
    base_counts = %{csv: 0, json: 0, log: 0, xml: 0}

    Enum.reduce(results, base_counts, fn %FileResult{type: type}, acc ->
      Map.update(acc, type, 1, &(&1 + 1))
    end)
  end

  defp count_by_status(results) do
    base_counts = %{success: 0, error: 0, partial: 0}

    Enum.reduce(results, base_counts, fn result, acc ->
      case result.status do
        :ok -> Map.update(acc, :success, 1, &(&1 + 1))
        :error -> Map.update(acc, :error, 1, &(&1 + 1))
        :partial -> Map.update(acc, :partial, 1, &(&1 + 1))
      end
    end)
  end

  defp mode_to_string(:sequential), do: "Sequential"
  defp mode_to_string(:parallel), do: "Parallel"
  defp mode_to_string(mode), do: to_string(mode) |> String.capitalize()

  # ============================================================================
  # Private Functions - UI/Output
  # ============================================================================

  defp print_processing_header(mode, file_count) do
    FProcess.UI.header(mode, file_count)
    # start progress if UI wants it (modes still control starting)
  end

  defp print_processing_summary(report) do
    # Use UI.summary to render friendly summary and errors list
    FProcess.UI.summary(report)
  end

  defp print_completion_message(report_path) do
    FProcess.UI.report_saved(report_path)
  end

  defp ensure_output_directory!(output_dir) do
    unless File.dir?(output_dir) do
      File.mkdir_p!(output_dir)
    end
  end
end
