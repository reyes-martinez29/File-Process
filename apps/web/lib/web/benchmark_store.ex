defmodule Web.BenchmarkStore do
  @moduledoc """
  GenServer that manages temporary benchmark file uploads.
  Automatically cleans up old uploads and their files.

  - Uploads older than 5 minutes are removed
  - Cleanup runs every minute
  - Files are deleted from filesystem when removed from store
  """
  use GenServer
  require Logger

  @table_name :benchmark_uploads
  @cleanup_interval :timer.minutes(1)
  @upload_ttl :timer.minutes(5)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stores benchmark upload files with current timestamp.
  """
  def put(benchmark_id, files) do
    timestamp = System.system_time(:second)
    :ets.insert(@table_name, {benchmark_id, files, timestamp})
    :ok
  end

  @doc """
  Retrieves benchmark files from store.
  Returns {:ok, files} or :error if not found or expired.
  """
  def get(benchmark_id) do
    case :ets.lookup(@table_name, benchmark_id) do
      [{^benchmark_id, files, timestamp}] ->
        if fresh?(timestamp) do
          {:ok, files}
        else
          # Upload expired, clean it up
          cleanup_files(files)
          :ets.delete(@table_name, benchmark_id)
          :error
        end

      [] ->
        :error
    end
  end

  @doc """
  Deletes benchmark upload and cleans up files.
  """
  def delete(benchmark_id) do
    case :ets.lookup(@table_name, benchmark_id) do
      [{^benchmark_id, files, _timestamp}] ->
        cleanup_files(files)
        :ets.delete(@table_name, benchmark_id)
        :ok

      [] ->
        :error
    end
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    Logger.info("BenchmarkStore started with table #{@table_name}")

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    count = cleanup_expired()

    if count > 0 do
      Logger.info("BenchmarkStore: Cleaned up #{count} expired uploads")
    end

    schedule_cleanup()
    {:noreply, state}
  end

  # Private Functions

  defp fresh?(timestamp, now \\ System.system_time(:second)) do
    now - timestamp < @upload_ttl / 1000
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired do
    now = System.system_time(:second)

    expired =
      :ets.tab2list(@table_name)
      |> Enum.filter(fn {_id, _files, timestamp} ->
        not fresh?(timestamp, now)
      end)

    Enum.each(expired, fn {id, files, _timestamp} ->
      cleanup_files(files)
      :ets.delete(@table_name, id)
    end)

    length(expired)
  end

  defp cleanup_files(files) do
    Enum.each(files, fn file ->
      path = file["path"]

      if File.exists?(path) do
        File.rm(path)
      end
    end)
  end
end
