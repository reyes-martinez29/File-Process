defmodule FProcess.Utils.Progress do
  @moduledoc """
  Simple progress indicator for parallel processing.

  Provides real-time feedback on processing progress without cluttering
  the output. Uses ANSI codes to update the same line.

  This is optional and can be disabled via configuration.
  """

  @doc """
  Start progress tracking.

  Initializes the progress display for a given total number of items.

  ## Parameters

  - `total` - Total number of items to process
  """
  @spec start(non_neg_integer()) :: :ok
  def start(total) do
    # Initialize with an empty bar
    show_bar(0, total)
    :ok
  end

  @doc """
  Update progress with current completion count.

  Updates the display to show current progress. Uses carriage return
  to overwrite the previous line.

  ## Parameters

  - `current` - Number of items completed
  - `total` - Total number of items
  """
  @spec update(non_neg_integer(), non_neg_integer()) :: :ok
  def update(current, total) when current <= total do
    show_bar(current, total)
    :ok
  end

  def update(_current, _total), do: :ok

  @doc """
  Complete and clear the progress indicator.

  Moves to a new line after progress is complete.
  """
  @spec stop() :: :ok
  def stop do
    IO.write("\n")
    :ok
  end

  @doc """
  Show progress bar with visual representation.

  Displays a progress bar with filled and empty segments.

  ## Parameters

  - `current` - Number of items completed
  - `total` - Total number of items
  - `width` - Width of the progress bar in characters (default: 40)
  """
  @spec show_bar(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: :ok
  def show_bar(current, total, width \\ 40) do
    percentage = if total > 0, do: current / total, else: 0.0
    filled = round(percentage * width)
    empty = width - filled

    filled_bar = String.duplicate("█", filled)
    empty_bar = String.duplicate("░", empty)
    percent_text = Float.round(percentage * 100, 1)

    # colored output: green filled, grey empty
    green = "\e[32m"
    grey = "\e[90m"
    reset = "\e[0m"

    IO.write("\rProgress: [#{green}#{filled_bar}#{reset}#{grey}#{empty_bar}#{reset}] #{percent_text}% (#{current}/#{total})")

    :ok
  end
end
