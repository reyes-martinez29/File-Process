defmodule FProcess.CLI do
  @moduledoc """
  Command Line Interface for the File Processor.

  Handles argument parsing and provides a user-friendly interface
  for running the file processor with different modes.
  """

  def main(args) do
    args
    |> parse_args()
    |> process_command()
  end

  # Parse command line arguments
  defp parse_args(args) do
    {opts, paths, invalid} =
      OptionParser.parse(args,
        strict: [
          help: :boolean,
          mode: :string,
          benchmark: :boolean,
          timeout: :integer,
          retries: :integer,
          output: :string,
          verbose: :boolean,
          workers: :integer
        ],
        aliases: [
          h: :help,
          m: :mode,
          b: :benchmark,
          t: :timeout,
          r: :retries,
          o: :output,
          v: :verbose,
          w: :workers
        ]
      )

    cond do
      opts[:help] || length(paths) == 0 ->
        :help

      length(invalid) > 0 ->
        {:error, "Invalid options: #{inspect(invalid)}"}

      opts[:benchmark] ->
        {:benchmark, determine_input(paths), opts}

      true ->
        {:process, determine_input(paths), opts}
    end
  end

  # Determine input type: single file, file list, or directory
  defp determine_input([single_path]) when is_binary(single_path) do
    single_path
  end

  defp determine_input(paths) when is_list(paths) and length(paths) > 1 do
    paths
  end

  defp determine_input(_), do: nil

  # =====================  PROCESS COMMANDS ========================================

  # Process the parsed command
  defp process_command(:help) do
    print_help()
  end

  defp process_command({:error, message}) do
    IO.puts("[ERROR] #{message}\n")
    print_help()
    System.halt(1)
  end

  defp process_command({:benchmark, input, opts}) do
    # Keep CLI output minimal: suppress library info logs
    Logger.configure(level: :warning)

    benchmark_opts = build_options(opts)

    # Ensure benchmark flag is present so Core.process saves the report
    benchmark_opts = Keyword.put(benchmark_opts, :benchmark, true)

    case FProcess.process(input, benchmark_opts) do
      {:error, reason} ->
        IO.puts("\n[ERROR] Benchmark failed: #{reason}")
        System.halt(1)

      {:ok, execution_report} ->
        data = Map.get(execution_report, :benchmark_data, %{})
        seq = Map.get(data, :sequential, %{})
        par = Map.get(data, :parallel, %{})
        comp = Map.get(data, :comparison, %{})

        IO.puts("\nBENCHMARK SUMMARY")
        IO.puts("Total files: #{Map.get(data, :total_files, execution_report.total_files)}")
        IO.puts("Sequential: #{Map.get(seq, :duration_ms, 0)} ms (avg #{Map.get(seq, :avg_time_per_file, 0)} ms/file) - Success: #{Map.get(seq, :success_count, 0)}")
        IO.puts("Parallel:   #{Map.get(par, :duration_ms, 0)} ms (avg #{Map.get(par, :avg_time_per_file, 0)} ms/file) - Success: #{Map.get(par, :success_count, 0)}")
        IO.puts("Speedup: #{Map.get(comp, :speedup_factor, 0)}x | Time saved: #{Map.get(comp, :time_saved_ms, 0)} ms (#{Map.get(comp, :time_saved_percent, 0)}%)")

        if Map.get(data, :skipped) do
          skipped = Map.get(data, :skipped)
          IO.puts("Skipped inputs: #{length(skipped)} (use --verbose for details)")
        end

        report_path = execution_report.report_path || "(not saved)"
        IO.puts("Report: #{report_path}")

        System.halt(0)
    end
  end

  defp process_command({:process, input, opts}) do
    # Keep CLI output minimal: switch Logger to warnings only so internal info doesn't clutter
    Logger.configure(level: :warning)

    process_opts = build_options(opts)

    case FProcess.process(input, process_opts) do
      {:ok, _execution_report} ->
        # UI already prints a friendly summary and report path; exit cleanly
        System.halt(0)

      {:error, reason} ->
        IO.puts("\n[ERROR] Processing failed: #{reason}")
        System.halt(1)
    end
  end


  # ================ Build options map from CLI flags ===========================
  defp build_options(opts) do
    base_opts = []

    base_opts =
      if mode = opts[:mode] do
        mode_atom = String.to_atom(mode)
        Keyword.put(base_opts, :mode, mode_atom)
      else
        base_opts
      end

    base_opts =
      if timeout = opts[:timeout] do
        Keyword.put(base_opts, :timeout, timeout)
      else
        base_opts
      end

    base_opts =
      if retries = opts[:retries] do
        Keyword.put(base_opts, :max_retries, retries)
      else
        base_opts
      end

    base_opts =
      if output = opts[:output] do
        Keyword.put(base_opts, :output_dir, output)
      else
        base_opts
      end

    base_opts =
      if opts[:verbose] do
        Keyword.put(base_opts, :verbose, true)
      else
        base_opts
      end

    base_opts =
      if workers = opts[:workers] do
        Keyword.put(base_opts, :max_workers, workers)
      else
        base_opts
      end

    base_opts
  end

  # ----------------- Print help message -------------
  defp print_help do
    IO.puts("""

    ======================================================================
                FILE PROCESSOR - Parallel File Processing
    ======================================================================

    DESCRIPTION:
        A high-performance file processing system that analyzes multiple
        file formats concurrently using Elixir processes. Parses files,
        extracts metrics, detects errors, and generates comprehensive
        reports with execution statistics.

    FEATURES:
        • Parallel processing with configurable concurrency
        • Automatic error detection and validation
        • Detailed metrics extraction per file type
        • Performance benchmarking (sequential vs parallel)
        • Comprehensive execution reports with timing stats
        • Retry mechanism for transient failures


    USAGE:
        fprocess <path> [options]
        fprocess <file1> <file2> ... [options]

    ARGUMENTS:
        <path>              Directory or file(s) to process

    OPTIONS:
        -h, --help          Show this help message
        -m, --mode MODE     Processing mode: sequential | parallel
                            (default: parallel)
        -b, --benchmark     Run benchmark (compare seq vs parallel)
        -t, --timeout MS    Timeout per file in milliseconds (default: 30000)
        -r, --retries N     Maximum retry attempts (default: 3)
        -w, --workers N     Max concurrent workers in parallel mode
                            (default: 8)
        -o, --output DIR    Output directory for reports (default: output)
        -v, --verbose       Show detailed processing information

    EXAMPLES:
        # Process directory
        fprocess ./data/valid

        # Process single file
        fprocess data/valid/ventas_enero.csv

        # Process multiple files
        fprocess data/valid/ventas_enero.csv data/valid/usuarios.json

        # Sequential mode
        fprocess ./data/valid --mode sequential

        # Benchmark
        fprocess ./data/valid --benchmark

        # Custom options
        fprocess ./data/valid -t 5000 -r 5 -o ./reports

        # Limit concurrent workers
        fprocess ./data/valid --workers 8

        # Verbose output
        fprocess ./data/valid --verbose

    SUPPORTED FORMATS:
        [CSV]  - Sales data files
                 Metrics: total sales, product performance, temporal analysis

        [JSON] - User and session data
                 Metrics: user stats, session patterns, activity analysis

        [LOG]  - System log files
                 Metrics: error rates, severity distribution, event patterns

        [XML]  - XML structured data
                 Metrics: structure analysis, element counts, data extraction

    OUTPUT:
        Generates timestamped reports in the output directory containing:
        • Execution summary (mode, duration, file counts)
        • Per-file results with metrics and status
        • Error details for failed files
        • Performance statistics and benchmarks

    """)
  end
end
