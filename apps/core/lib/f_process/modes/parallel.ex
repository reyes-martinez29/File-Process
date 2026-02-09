defmodule FProcess.Modes.Parallel do
  @moduledoc """
  Parallel processing mode using Task.async_stream.

  Processes multiple files concurrently with controlled concurrency.
  Uses Elixir's Task module for robust parallel execution with automatic
  error handling and timeout management.

  This mode demonstrates Elixir's high-level concurrency abstractions
  and shows significant performance improvements over sequential processing.
  """

  alias FProcess.FileProcessor
  alias FProcess.Structs.FileResult
  alias FProcess.Utils.Progress
  require Logger

  @type classified_files :: list({atom(), String.t()})
  @type config :: map()

  @doc """
  Run parallel processing on a list of classified files.

  Uses Task.async_stream to process files concurrently with controlled
  concurrency, automatic error handling, and timeout management.

  ## Parameters

  - `classified_files` - List of {type, path} tuples
  - `config` - Configuration map with timeout, max_workers, retries, etc.

  ## Returns

  List of FileResult structs, one per input file
  """
  @spec run(classified_files(), config()) :: list(FileResult.t())
  def run(classified_files, config \\ %{})

  def run([], _config) do
    []
  end

  def run(classified_files, config) do
    total = length(classified_files)
    max_workers = Map.get(config, :max_workers, 8)
    timeout = Map.get(config, :timeout, 30_000)

    Logger.info("Parallel mode: Processing #{total} files (max #{max_workers} concurrent workers)...\n")

    # Show progress if enabled
    if Map.get(config, :show_progress, true) do
      Progress.start(total)
    end

    # Process files with controlled concurrency using Task.async_stream
    results = classified_files
    |> Task.async_stream(
      fn file -> process_with_retry(file, config) end,
      max_concurrency: max_workers,
      timeout: timeout,
      on_timeout: :kill_task
    )
    |> Enum.with_index(1)
    |> Enum.map(fn {result, index} ->
      # Update progress
      if Map.get(config, :show_progress, true) do
        Progress.update(index, total)
      end

      # Handle result
      case result do
        {:ok, file_result} ->
          file_result
        {:exit, reason} ->
          create_crash_result(classified_files, index, reason)
      end
    end)

    # Stop progress indicator
    if Map.get(config, :show_progress, true) do
      Progress.stop()
    end

    Logger.info("\nAll workers completed.\n")

    results
  end

  # ============================================================================
  # Private Functions - Processing
  # ============================================================================

  defp process_with_retry(file, config, attempt \\ 1) do
    max_retries = Map.get(config, :max_retries, 3)
    result = FileProcessor.process(file, config)

    # Retry only for transient errors (IO/timeouts/crashes), skip for validation errors
    if result.status == :error and attempt < max_retries and retryable_error?(result) do
      retry_delay = Map.get(config, :retry_delay, 1_000)
      Process.sleep(retry_delay)
      process_with_retry(file, config, attempt + 1)
    else
      result
    end
  end

  defp retryable_error?(%FileResult{errors: errors}) when is_list(errors) do
    transient_re = ~r/failed to read|timeout|timed out|processing timeout|worker process crashed|killed|exit:/
    validation_re = ~r/validation|invalid|invalid json|csv validation/i

    Enum.any?(errors, fn
      msg when is_binary(msg) ->
        lowered = String.downcase(msg)
        String.match?(lowered, transient_re) and not String.match?(lowered, validation_re)
      _ -> false
    end)
  end

  # ============================================================================
  # Private Functions - Error Handling
  # ============================================================================

  defp create_crash_result(files, index, reason) do
    {type, path} = Enum.at(files, index - 1, {:unknown, "unknown"})

    %FileResult{
      path: path,
      type: type,
      filename: Path.basename(path),
      status: :error,
      errors: ["Task crashed or timed out: #{inspect(reason)}"],
      duration_ms: 0
    }
  end
end
