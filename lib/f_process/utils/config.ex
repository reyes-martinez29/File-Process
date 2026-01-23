defmodule FProcess.Utils.Config do
  @moduledoc """
  Centralized configuration for the file processor.

  Provides default values and allows runtime overrides through options.
  This makes the system configurable without hardcoding values.
  """

  @default_config %{
    timeout: 30_000,
    max_retries: 3,
    retry_delay: 1_000,
    output_dir: "output",
    show_progress: true,
    max_workers: 8
  }

  @doc """
  Get the default timeout for file processing in milliseconds.
  """
  def timeout, do: @default_config.timeout

  @doc """
  Get the maximum number of retry attempts for failed files.
  """
  def max_retries, do: @default_config.max_retries

  @doc """
  Get the delay between retry attempts in milliseconds.
  """
  def retry_delay, do: @default_config.retry_delay

  @doc """
  Get the default output directory for reports.
  """
  def output_dir, do: @default_config.output_dir

  @doc """
  Get complete configuration with optional overrides.

  ## Examples

      iex> Config.get()
      %{timeout: 30_000, max_retries: 3, ...}

      iex> Config.get(timeout: 5000, max_retries: 5)
      %{timeout: 5000, max_retries: 5, ...}

      iex> Config.get([{:timeout, 5000}])
      %{timeout: 5000, max_retries: 3, ...}
  """
  def get(opts \\ []) when is_list(opts) do
    @default_config
    |> Map.merge(normalize_opts(opts))
    |> validate_config!()
  end

  @doc """
  Validate configuration values.
  Returns :ok if valid, raises if invalid.
  """
  def validate!(config) when is_map(config) do
    with :ok <- validate_timeout(config.timeout),
         :ok <- validate_retries(config.max_retries),
         :ok <- validate_retry_delay(config.retry_delay),
         :ok <- validate_output_dir(config.output_dir) do
      :ok
    else
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  # Private functions

  defp normalize_opts(opts) do
    Enum.into(opts, %{})
  end

  defp validate_config!(config) do
    validate!(config)
    config
  end

  defp validate_timeout(timeout) when is_integer(timeout) and timeout > 0, do: :ok
  defp validate_timeout(_), do: {:error, "timeout must be a positive integer"}

  defp validate_retries(retries) when is_integer(retries) and retries >= 0, do: :ok
  defp validate_retries(_), do: {:error, "max_retries must be a non-negative integer"}

  defp validate_retry_delay(delay) when is_integer(delay) and delay >= 0, do: :ok
  defp validate_retry_delay(_), do: {:error, "retry_delay must be a non-negative integer"}

  defp validate_output_dir(dir) when is_binary(dir) and byte_size(dir) > 0, do: :ok
  defp validate_output_dir(_), do: {:error, "output_dir must be a non-empty string"}
end
