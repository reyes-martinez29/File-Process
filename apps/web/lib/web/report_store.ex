defmodule Web.ReportStore do
  @moduledoc """
  GenServer that manages the ETS table for storing processing reports.
  Automatically cleans up old reports to prevent memory leaks.

  - Reports older than 1 hour are removed
  - Cleanup runs every 15 minutes
  - Thread-safe operations
  """
  use GenServer
  require Logger

  @table_name :reports_store
  @cleanup_interval :timer.minutes(15)
  @report_ttl :timer.hours(1)

  # Client API

  @doc """
  Starts the ReportStore GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stores a report in ETS with current timestamp.
  """
  def put(report_id, report) do
    timestamp = System.system_time(:second)
    :ets.insert(@table_name, {report_id, report, timestamp})
    :ok
  end

  @doc """
  Retrieves a report from ETS.
  Returns {:ok, report} or :error if not found or expired.
  """
  def get(report_id) do
    case :ets.lookup(@table_name, report_id) do
      [{^report_id, report, timestamp}] ->
        if fresh?(timestamp) do
          {:ok, report}
        else
          # Report expired, delete it
          :ets.delete(@table_name, report_id)
          :error
        end

      [] ->
        :error
    end
  end

  @doc """
  Manually triggers cleanup of old reports.
  Returns the number of reports deleted.
  """
  def cleanup do
    GenServer.call(__MODULE__, :cleanup)
  end

  @doc """
  Returns statistics about the report store.
  """
  def stats do
    total = :ets.info(@table_name, :size)
    now = System.system_time(:second)

    expired =
      :ets.tab2list(@table_name)
      |> Enum.count(fn {_id, _report, timestamp} ->
        not fresh?(timestamp, now)
      end)

    %{
      total_reports: total,
      expired_reports: expired,
      active_reports: total - expired
    }
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table if it doesn't exist
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
        Logger.info("Created ETS table: #{@table_name}")

      _tid ->
        Logger.info("ETS table #{@table_name} already exists")
    end

    # Schedule first cleanup
    schedule_cleanup()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    deleted_count = do_cleanup()

    Logger.info("ReportStore cleanup: removed #{deleted_count} expired reports")

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, state}
  end

  @impl true
  def handle_call(:cleanup, _from, state) do
    deleted_count = do_cleanup()
    {:reply, deleted_count, state}
  end

  # Private Functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp do_cleanup do
    now = System.system_time(:second)

    expired_reports =
      :ets.tab2list(@table_name)
      |> Enum.filter(fn {_id, _report, timestamp} ->
        not fresh?(timestamp, now)
      end)

    Enum.each(expired_reports, fn {report_id, _report, _timestamp} ->
      :ets.delete(@table_name, report_id)
    end)

    length(expired_reports)
  end

  defp fresh?(timestamp, now \\ System.system_time(:second)) do
    age_seconds = now - timestamp
    age_ms = age_seconds * 1000
    age_ms < @report_ttl
  end
end
