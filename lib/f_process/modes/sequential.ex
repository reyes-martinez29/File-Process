defmodule FProcess.Modes.Sequential do
  @moduledoc """
  Sequential processing mode.

  Processes files one by one in order. This is the simplest mode
  and serves as the baseline for performance comparisons.

  Each file is processed completely before moving to the next one,
  making this mode easy to understand and debug.
  """

  alias FProcess.FileProcessor
  alias FProcess.Structs.FileResult
  alias FProcess.Utils.Progress
  require Logger

  @type classified_files :: list({atom(), String.t()})
  @type config :: map()

  @doc """
  Run sequential processing on a list of classified files.

  Processes each file in order, collecting results as a list.

  ## Parameters

  - `classified_files` - List of {type, path} tuples
  - `config` - Configuration map with timeout, retries, etc.

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

    if Map.get(config, :show_progress, true) do
      Progress.start(total)
    end

    results =
      classified_files
      |> Enum.with_index(1)
      |> Enum.map(fn {file, index} ->
        result = process_with_retry(file, config)

        if Map.get(config, :show_progress, true) do
          Progress.update(index, total)
        end

        result
      end)

    if Map.get(config, :show_progress, true) do
      Progress.stop()
    end

    results
  end

  # ============================================================================
  # Private Functions
  # ============================================================================


  defp process_with_retry(file, config, attempt \\ 1) do
    max_retries = Map.get(config, :max_retries, 3)

    result = FileProcessor.process(file, config)


    # DEBUG: log whether error is considered retryable
    # optional debug: Logger.debug("Retryable check for #{inspect(file)}: #{inspect(retryable_error?(result))}")

    # Retry only for transient errors (IO/timeouts/crashes), skip for validation errors
    if result.status == :error and attempt < max_retries and retryable_error?(result) do
      retry_delay = Map.get(config, :retry_delay, 1_000)
      Logger.info("[RETRY #{attempt}] Retrying #{inspect(file)}...")
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

  # format_type removed — keep sequential output minimal (use Progress bar)
end
