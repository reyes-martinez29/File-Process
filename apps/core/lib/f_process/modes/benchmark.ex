defmodule FProcess.Modes.Benchmark do
  @moduledoc """
  Benchmark mode that compares sequential vs parallel processing.

  Runs the same set of files through both processing modes and
  provides detailed performance comparison metrics.
  """

  alias FProcess.Modes.{Sequential, Parallel}
  require Logger

  @type classified_files :: list({atom(), String.t()})
  @type config :: map() | keyword()

  @doc """
  Run benchmark comparison and return results in ExecutionReport format.
  """
    alias FProcess.Structs.FileResult

    @spec run(classified_files(), config()) :: {list(FileResult.t()), map()}
  def run(classified_files, config \\ %{})

  def run([], _config) do
    {[], %{}}
  end

  def run(classified_files, config) do
    total_files = length(classified_files)

    Logger.info("\n" <> String.duplicate("=", 70))
    Logger.info("BENCHMARK MODE")
    Logger.info(String.duplicate("=", 70))
    Logger.info("Files to process: #{total_files}")
    Logger.info("Running both sequential and parallel modes...\n")

    # Convert config to map and add show_progress: false
    benchmark_config = config
      |> Enum.into(%{})
      |> Map.put(:show_progress, false)

    # Run sequential mode
    Logger.info("--- Sequential Mode ---")
    {seq_time, seq_results, seq_mem_kb} = time_execution(fn ->
      Sequential.run(classified_files, benchmark_config)
    end)

    Logger.info("\n--- Parallel Mode ---")
    {par_time, par_results, par_mem_kb} = time_execution(fn ->
      Parallel.run(classified_files, benchmark_config)
    end)

    # Build comparison report
    benchmark_data = build_benchmark_data(
      classified_files,
      seq_time,
      seq_results,
      seq_mem_kb,
      par_time,
      par_results,
      par_mem_kb
    )

    # Print comparison
    print_benchmark_results(benchmark_data)

    # Return parallel results with benchmark data embedded
    # We'll use the parallel results as the "official" results
    # and attach benchmark data for the report
    {par_results, benchmark_data}
  end

  # ============================================================================
  # Private Functions - Timing
  # ============================================================================

  defp time_execution(function) do
    mem_before = :erlang.memory(:total)
    start_time = System.monotonic_time(:millisecond)
    result = function.()
    end_time = System.monotonic_time(:millisecond)
    mem_after = :erlang.memory(:total)

    duration = end_time - start_time
    # Use the higher of before/after as a simple peak approximation (in KB)
    mem_peak_kb = max(mem_before, mem_after) / 1024

    {duration, result, Float.round(mem_peak_kb, 2)}
  end

  # ============================================================================
  # Private Functions - Report Building
  # ============================================================================

  defp build_benchmark_data(files, seq_time, seq_results, seq_mem_kb, par_time, par_results, par_mem_kb) do
    speedup = if par_time > 0, do: seq_time / par_time, else: 0.0

    %{
      total_files: length(files),
      sequential: %{
        duration_ms: seq_time,
        duration_sec: seq_time / 1000,
        success_count: count_successful(seq_results),
        error_count: count_errors(seq_results),
        avg_time_per_file: seq_time / max(length(files), 1),
        memory_kb: seq_mem_kb
      },
      parallel: %{
        duration_ms: par_time,
        duration_sec: par_time / 1000,
        success_count: count_successful(par_results),
        error_count: count_errors(par_results),
        avg_time_per_file: par_time / max(length(files), 1),
        memory_kb: par_mem_kb
      },
      comparison: %{
        speedup_factor: Float.round(speedup, 2),
        time_saved_ms: seq_time - par_time,
        time_saved_percent: Float.round((seq_time - par_time) / max(seq_time, 1) * 100, 1),
        faster_mode: if(par_time < seq_time, do: :parallel, else: :sequential)
      },
      processes_used: length(files)
    }
  end

  defp count_successful(results) do
    Enum.count(results, fn r -> r.status == :ok end)
  end

  defp count_errors(results) do
    Enum.count(results, fn r -> r.status == :error end)
  end

  # ============================================================================
  # Private Functions - Output
  # ============================================================================

  defp print_benchmark_results(data) do
    Logger.info("\n" <> String.duplicate("=", 70))
    Logger.info("BENCHMARK RESULTS")
    Logger.info(String.duplicate("=", 70))

    Logger.info("\nSequential Mode:")
    Logger.info("  Duration:        #{Float.round(data.sequential.duration_sec, 3)}s")
    Logger.info("  Avg per file:    #{Float.round(data.sequential.avg_time_per_file, 2)}ms")
    Logger.info("  Success:         #{data.sequential.success_count}/#{data.total_files}")

    Logger.info("\nParallel Mode:")
    Logger.info("  Duration:        #{Float.round(data.parallel.duration_sec, 3)}s")
    Logger.info("  Avg per file:    #{Float.round(data.parallel.avg_time_per_file, 2)}ms")
    Logger.info("  Success:         #{data.parallel.success_count}/#{data.total_files}")
    Logger.info("  Memory (peak):   #{Float.round(data.parallel.memory_kb / 1024, 3)} MB")

    Logger.info("\nComparison:")
    Logger.info("  Speedup:         #{data.comparison.speedup_factor}x")
    Logger.info("  Time saved:      #{data.comparison.time_saved_ms}ms (#{data.comparison.time_saved_percent}%)")
    Logger.info("  Winner:          #{format_mode(data.comparison.faster_mode)}")
    Logger.info("  Memory (seq vs par): #{Float.round(data.sequential.memory_kb / 1024, 3)} MB vs #{Float.round(data.parallel.memory_kb / 1024, 3)} MB")

    print_verdict(data.comparison.speedup_factor)

    Logger.info(String.duplicate("=", 70))
  end

  defp print_verdict(speedup) when speedup >= 2.0 do
    Logger.info("\nVerdict: Parallel processing shows SIGNIFICANT improvement!")
  end

  defp print_verdict(speedup) when speedup >= 1.2 do
    Logger.info("\nVerdict: Parallel processing shows moderate improvement.")
  end

  defp print_verdict(speedup) when speedup >= 0.9 do
    Logger.info("\nVerdict: Both modes perform similarly.")
  end

  defp print_verdict(_speedup) do
    Logger.info("\nVerdict: Sequential might be better for this workload.")
  end

  defp format_mode(:parallel), do: "Parallel"
  defp format_mode(:sequential), do: "Sequential"
end
