defmodule FProcess.Metrics.CSVMetrics do
  @moduledoc """
  Calculates metrics for CSV sales data.

  Metrics extracted:
  - Total sales amount
  - Number of unique products
  - Best-selling product (by quantity)
  - Top category by revenue
  - Average discount
  - Date range
  """

  alias FProcess.Structs.Sale

  @doc """
  Calculate all metrics from a list of Sale structs.

  Returns:
  - `{:ok, metrics_map}` - Metrics calculated successfully
  - `{:error, reason}` - Calculation failed
  """
  @spec calculate(list(Sale.t())) :: {:ok, map()} | {:error, String.t()}
  def calculate([]), do: {:error, "No sales data to analyze"}

  def calculate(sales) when is_list(sales) do
    metrics = %{
      total_sales: calculate_total_sales(sales),
      unique_products: count_unique_products(sales),
      products: get_unique_products(sales),
      best_selling_product: find_best_selling_product(sales),
      top_category: find_top_category(sales),
      average_discount: calculate_average_discount(sales),
      date_range: calculate_date_range(sales),
      total_records: length(sales),
      total_quantity: calculate_total_quantity(sales)
    }

    {:ok, metrics}
  end

  def calculate(_invalid) do
    {:error, "Invalid sales data format"}
  end

  # ============================================================================
  # Private Functions - Metric Calculations
  # ============================================================================

  defp calculate_total_sales(sales) do
    sales
    |> Enum.map(& &1.total)
    |> Enum.sum()
    |> Float.round(2)
  end

  defp count_unique_products(sales) do
    sales
    |> Enum.map(& &1.product)
    |> Enum.uniq()
    |> length()
  end

  defp find_best_selling_product(sales) do
    sales
    |> Enum.group_by(& &1.product)
    |> Enum.map(fn {product, sales_list} ->
      total_quantity = Enum.sum(Enum.map(sales_list, & &1.quantity))
      {product, total_quantity}
    end)
    |> case do
      [] -> {"N/A", 0}
      list -> Enum.max_by(list, fn {_product, quantity} -> quantity end)
    end
    |> case do
      {product, quantity} -> %{name: product, quantity: quantity}
    end
  end

  defp find_top_category(sales) do
    sales
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, sales_list} ->
      total_revenue = Enum.sum(Enum.map(sales_list, & &1.total))
      {category, total_revenue}
    end)
    |> case do
      [] -> {"N/A", 0.0}
      list -> Enum.max_by(list, fn {_category, revenue} -> revenue end)
    end
    |> case do
      {category, revenue} -> %{name: category, revenue: Float.round(revenue, 2)}
    end
  end

  defp calculate_average_discount(sales) do
    if length(sales) > 0 do
      total_discount = Enum.sum(Enum.map(sales, & &1.discount))
      Float.round(total_discount / length(sales), 2)
    else
      0.0
    end
  end

  defp calculate_date_range(sales) do
    dates =
      sales
      |> Enum.map(& &1.date)
      |> Enum.reject(&is_nil/1)

    case dates do
      [] ->
        %{from: nil, to: nil}

      dates ->
        # dates are expected to be Date structs; use Enum.min/Enum.max directly
        min_date = Enum.min(dates)
        max_date = Enum.max(dates)
        %{from: Date.to_string(min_date), to: Date.to_string(max_date)}
    end
  end

  defp calculate_total_quantity(sales) do
    Enum.sum(Enum.map(sales, & &1.quantity))
  end

  defp get_unique_products(sales) do
    sales
    |> Enum.map(& &1.product)
    |> Enum.uniq()
  end
end
