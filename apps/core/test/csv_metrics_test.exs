defmodule FProcess.CSVMetricsTest do
  use ExUnit.Case, async: true

  alias FProcess.Parsers.CSVParser
  alias FProcess.Metrics.CSVMetrics

  setup do
    {:ok, sales} = CSVParser.parse("data/valid/ventas_enero.csv")
    {:ok, sales: sales}
  end

  test "calculates CSV metrics correctly", %{sales: sales} do
    assert {:ok, metrics} = CSVMetrics.calculate(sales)
    assert metrics.total_records == 30
    assert_in_delta metrics.total_sales, 24399.93, 1.0
    assert metrics.unique_products > 0
    assert is_map(metrics.date_range)
    assert metrics.total_quantity == 171
  end
end
