defmodule FProcess.CSVMetricsExtraTest do
  use ExUnit.Case, async: true

  alias FProcess.Metrics.CSVMetrics

  test "calculate on empty list returns error" do
    assert {:error, _} = CSVMetrics.calculate([])
  end

  test "single sale metrics" do
    sale = %FProcess.Structs.Sale{
      date: ~D[2020-01-01],
      product: "X",
      category: "C",
      unit_price: 10.0,
      quantity: 2,
      discount: 0.0,
      total: 20.0
    }

    assert {:ok, metrics} = CSVMetrics.calculate([sale])
    assert metrics.total_sales == 20.0
    assert metrics.total_records == 1
    assert metrics.unique_products == 1
  end

  test "tie best selling product returns correct quantity" do
    s1 = %FProcess.Structs.Sale{product: "A", category: "c1", unit_price: 10.0, quantity: 5, discount: 0.0, total: 50.0}
    s2 = %FProcess.Structs.Sale{product: "B", category: "c2", unit_price: 12.0, quantity: 5, discount: 0.0, total: 60.0}
    assert {:ok, metrics} = CSVMetrics.calculate([s1, s2])
    assert metrics.best_selling_product.quantity == 5
    assert metrics.unique_products == 2
  end

  test "top category by revenue computed" do
    s1 = %FProcess.Structs.Sale{product: "A", category: "cat1", unit_price: 30.0, quantity: 1, discount: 0.0, total: 30.0}
    s2 = %FProcess.Structs.Sale{product: "B", category: "cat2", unit_price: 50.0, quantity: 1, discount: 0.0, total: 50.0}
    assert {:ok, metrics} = CSVMetrics.calculate([s1, s2])
    assert metrics.top_category.name == "cat2"
  end

  test "average discount computed" do
    s1 = %FProcess.Structs.Sale{product: "A", category: "c", unit_price: 10.0, quantity: 1, discount: 10.0, total: 9.0}
    s2 = %FProcess.Structs.Sale{product: "B", category: "c", unit_price: 10.0, quantity: 1, discount: 0.0, total: 10.0}
    assert {:ok, metrics} = CSVMetrics.calculate([s1, s2])
    assert_in_delta metrics.average_discount, 5.0, 0.1
  end
end
