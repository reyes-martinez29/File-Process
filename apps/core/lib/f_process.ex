defmodule FProcess do
  @moduledoc """
  Main entry point for the File Processing System.

  This module provides a clean, user-friendly API for processing files
  in different modes:
  - Sequential: Process files one by one in order
  - Parallel: Process files concurrently using Elixir processes
  - Benchmark: Compare performance between sequential and parallel modes

  The module handles input normalization and delegates to the Core module
  for actual processing orchestration.

  ## Supported File Types

  - CSV  (`.csv`)  - Sales data
  - JSON (`.json`) - User and session data
  - LOG  (`.log`)  - System logs
  - XML  (`.xml`)  - XML structured data

  ## Examples

      # Process a directory (recursively)
      FProcess.process("./data/valid")

      # Process a single file
      FProcess.process("data/ventas_enero.csv")

      # Process multiple specific files
      FProcess.process(["file1.csv", "file2.json"])

      # Process with custom options
      FProcess.process("./data", mode: :sequential, timeout: 10_000)

      # Run benchmark comparison
      FProcess.process("./data/valid", benchmark: true)
  """

  alias FProcess.Core
  alias FProcess.FileDiscovery
  require Logger

  @type process_option ::
    {:mode, :sequential | :parallel} |
    {:timeout, pos_integer()} |
    {:max_workers, pos_integer()} |
    {:max_retries, non_neg_integer()} |
    {:output_dir, String.t()} |
    {:benchmark, boolean()} |
    {:verbose, boolean()}

  @type process_result :: {:ok, FProcess.Structs.ExecutionReport.t()} | {:error, String.t()}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Process files from any input type.

  This is the universal entry point that accepts:
  - A directory path (will scan recursively)
  - A single file path
  - A list of file paths

  ## Options

  - `:mode` - Processing mode: `:sequential` or `:parallel` (default: `:parallel`)
  - `:timeout` - Timeout per file in milliseconds (default: 30,000)
  - `:max_workers` - Maximum concurrent workers for parallel mode (default: 8)
  - `:max_retries` - Maximum retry attempts for failed files (default: 3)
  - `:output_dir` - Output directory for reports (default: "output")
  - `:benchmark` - Enable benchmark mode for performance comparison (default: false)
  - `:verbose` - Enable verbose logging (default: false)

  ## Returns

  - `{:ok, execution_report}` - Success with detailed report
  - `{:error, reason}` - Failure with error message

  ## Examples

      # Process directory
      FProcess.process("./data/valid")

      # Process with sequential mode
      FProcess.process("./data", mode: :sequential)

      # Process with custom timeout
      FProcess.process("./data", timeout: 5000, max_retries: 5)
  """
  @spec process(String.t() | list(String.t()), list(process_option())) :: process_result()
  def process(input, opts \\ []) do
    case FileDiscovery.normalize(input) do
      {:ok, %{files: classified_files, skipped: skipped}} ->
        if Keyword.get(opts, :verbose, false) do
          print_discovery_summary(classified_files, input)
        end

        case Core.process(classified_files, opts) do
          {:ok, execution_report} ->
            # If there were skipped files, attach them as error FileResults
            if skipped != [] do
              error_results = Enum.map(skipped, fn
                {path, reason} when is_binary(reason) ->
                  p = if is_binary(path) and path != nil, do: path, else: "unknown"
                  fr = FProcess.Structs.FileResult.new(p, :unknown)
                  FProcess.Structs.FileResult.error(fr, reason, 0)

                reason when is_binary(reason) ->
                  fr = FProcess.Structs.FileResult.new("unknown", :unknown)
                  FProcess.Structs.FileResult.error(fr, reason, 0)
              end)

              # Update report counts and results
              total = execution_report.total_files + length(error_results)
              error_count = execution_report.error_count + length(error_results)

              execution_report = %{
                execution_report
                | results: execution_report.results ++ error_results,
                  total_files: total,
                  error_count: error_count
              }

              {:ok, execution_report}
            else
              {:ok, execution_report}
            end

          other -> other
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Process all files in a directory (recursively).

  Convenience function that calls `process/2`.
  """
  @spec process_directory(String.t(), list(process_option())) :: process_result()
  def process_directory(directory, opts \\ []) when is_binary(directory) do
    process(directory, opts)
  end

  @doc """
  Process a list of specific files.

  Convenience function that calls `process/2`.
  """
  @spec process_files(list(String.t()), list(process_option())) :: process_result()
  def process_files(file_list, opts \\ []) when is_list(file_list) do
    process(file_list, opts)
  end

  @doc """
  Process a single file.

  Convenience function that calls `process/2`.
  """
  @spec process_file(String.t(), list(process_option())) :: process_result()
  def process_file(file_path, opts \\ []) when is_binary(file_path) do
    process(file_path, opts)
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp print_discovery_summary(classified_files, input) do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("File Discovery Summary")
    IO.puts(String.duplicate("=", 70))

    print_input_info(input)
    print_file_summary(classified_files)
    print_directory_tree(classified_files)

    IO.puts(String.duplicate("=", 70) <> "\n")
  end

  defp print_input_info(input) when is_binary(input) do
    type = cond do
      File.dir?(input) -> "Directory"
      File.regular?(input) -> "Single File"
      true -> "Path"
    end

    IO.puts("Input Type:     #{type}")
    IO.puts("Input Path:     #{input}")
  end

  defp print_input_info(input) when is_list(input) do
    IO.puts("Input Type:     File List")
    IO.puts("File Count:     #{length(input)}")
  end

  defp print_file_summary(classified_files) do
    # Group by type
    grouped = Enum.group_by(classified_files, fn {type, _path} -> type end)

    total = length(classified_files)
    IO.puts("\nTotal Files:    #{total}")
    IO.puts("By Type:")

    grouped
    |> Enum.sort_by(fn {type, _} -> type end)
    |> Enum.each(fn {type, files} ->
      count = length(files)
      percentage = Float.round(count / total * 100, 1)
      IO.puts("  [#{format_type(type)}] #{count} (#{percentage}%)")
    end)
  end

  defp print_directory_tree(classified_files) do
    # Group by directory
    by_dir =
      classified_files
      |> Enum.group_by(fn {_type, path} -> Path.dirname(path) end)
      |> Enum.sort_by(fn {dir, _} -> dir end)

    if length(by_dir) > 1 do
      IO.puts("\nFiles by Directory:")

      Enum.each(by_dir, fn {dir, files} ->
        # Count by type in this directory
        type_counts =
          files
          |> Enum.group_by(fn {type, _} -> type end)
          |> Enum.map(fn {type, files} -> {type, length(files)} end)
          |> Enum.sort_by(fn {type, _} -> type end)

        type_str =
          type_counts
          |> Enum.map(fn {type, count} -> "#{count} #{type}" end)
          |> Enum.join(", ")

        IO.puts("  [DIR] #{dir}/ - #{length(files)} files (#{type_str})")
      end)
    end
  end

  defp format_type(:csv), do: "CSV "
  defp format_type(:json), do: "JSON"
  defp format_type(:log), do: "LOG "
  defp format_type(:xml), do: "XML "
  defp format_type(type), do: String.upcase(to_string(type))
end
