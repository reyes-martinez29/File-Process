defmodule FProcess.LogMetricsExtraTest do
  use ExUnit.Case, async: true

  alias FProcess.Metrics.LogMetrics
  alias FProcess.Structs.LogEntry

  test "level distribution and counts" do
    entries = [
      %LogEntry{level: "INFO", component: "a", message: "ok", hour: 1},
      %LogEntry{level: "ERROR", component: "a", message: "fail", hour: 1},
      %LogEntry{level: "ERROR", component: "b", message: "fail2", hour: 2}
    ]

    assert {:ok, metrics} = LogMetrics.calculate(entries)
    assert metrics.total_entries == 3
    assert metrics.critical_errors_count == 2
    assert metrics.level_distribution["ERROR"].count == 2
  end

  test "most frequent errors and components" do
    entries = [
      %LogEntry{level: "ERROR", component: "a", message: "X"},
      %LogEntry{level: "ERROR", component: "a", message: "X"},
      %LogEntry{level: "ERROR", component: "b", message: "Y"}
    ]

    assert {:ok, metrics} = LogMetrics.calculate(entries)
    assert hd(metrics.most_frequent_errors).count == 2
    assert hd(metrics.top_error_components).error_count >= 1
  end

  test "hourly distribution computed" do
    entries = [
      %LogEntry{level: "INFO", component: "a", message: "m", hour: 0},
      %LogEntry{level: "INFO", component: "a", message: "m", hour: 0},
      %LogEntry{level: "INFO", component: "a", message: "m", hour: 2}
    ]

    assert {:ok, metrics} = LogMetrics.calculate(entries)
    assert Enum.any?(metrics.hourly_distribution, fn d -> d.hour == 0 and d.count == 2 end)
  end

  test "error patterns detection" do
    entries = [
      %LogEntry{level: "ERROR", component: "db", message: "Timeout while connecting"},
      %LogEntry{level: "ERROR", component: "db", message: "Connection refused"},
      %LogEntry{level: "ERROR", component: "api", message: "Timeout occurred"}
    ]

    assert {:ok, metrics} = LogMetrics.calculate(entries)
    assert Enum.any?(metrics.error_patterns, fn p -> String.contains?(p.pattern, "Timeout") end)
  end
end
