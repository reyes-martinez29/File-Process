defmodule FProcess.IntegrationTest do
  use ExUnit.Case, async: false

  test "process single csv file returns execution report" do
    assert {:ok, report} = FProcess.process_file("data/valid/ventas_enero.csv", mode: :sequential)
    assert is_map(report)
    assert report.total_files >= 1
    assert Map.has_key?(report, :results)
  end

  test "process directory returns ok report" do
    # Keep this reasonably small by using the valid data directory
    assert {:ok, report} = FProcess.process("data/valid", mode: :sequential)
    assert is_map(report)
    assert report.total_files > 0
  end
end
