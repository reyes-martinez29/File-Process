defmodule FProcess.Metrics.XMLMetrics do
  @moduledoc """
  Calculates metrics for XML product catalog files.

  Metrics extracted:
  - Total products
  - Total stock value
  - Products by category
  - Total inventory value
  - Average price
  - Low stock alerts
  - Top suppliers
  """

  @doc """
  Calculate all metrics from parsed XML data.

  Expects data in the format:
  %{
    metadata: %{...},
    products: [%{id, name, category, price, stock, supplier}, ...],
    total_products: integer,
    total_stock: integer,
    categories: [...]
  }

  Returns:
  - `{:ok, metrics_map}` - Metrics calculated successfully
  - `{:error, reason}` - Calculation failed
  """
  @spec calculate(map()) :: {:ok, map()} | {:error, String.t()}
  def calculate(%{products: products} = data) when is_list(products) do
    metrics = %{
      total_products: length(products),
      total_stock_units: calculate_total_stock(products),
      total_inventory_value: calculate_inventory_value(products),
      average_price: calculate_average_price(products),
      categories_count: length(Map.get(data, :categories, [])),
      products_by_category: group_by_category(products),
      low_stock_items: find_low_stock_items(products, 10),
      top_suppliers: find_top_suppliers(products, 5),
      price_range: calculate_price_range(products),
      most_expensive_product: find_most_expensive(products),
      metadata: Map.get(data, :metadata, %{})
    }

    {:ok, metrics}
  end

  def calculate(_invalid) do
    {:error, "Invalid XML data format. Expected products list"}
  end

  # ============================================================================
  # Private Functions - Stock Metrics
  # ============================================================================

  defp calculate_total_stock(products) do
    products
    |> Enum.map(& &1.stock)
    |> Enum.reject(&is_nil/1)
    |> Enum.sum()
  end

  defp calculate_inventory_value(products) do
    products
    |> Enum.map(fn product ->
      price = product.price || 0.0
      stock = product.stock || 0
      price * stock
    end)
    |> Enum.sum()
    |> Float.round(2)
  end

  defp find_low_stock_items(products, threshold) do
    products
    |> Enum.filter(fn product ->
      stock = product.stock || 0
      stock > 0 and stock <= threshold
    end)
    |> Enum.map(fn product ->
      %{
        name: product.name,
        stock: product.stock,
        category: product.category
      }
    end)
    |> Enum.sort_by(& &1.stock)
  end

  # ============================================================================
  # Private Functions - Price Metrics
  # ============================================================================

  defp calculate_average_price(products) do
    prices =
      products
      |> Enum.map(& &1.price)
      |> Enum.reject(&is_nil/1)

    case prices do
      [] ->
        0.0

      prices ->
        total = Enum.sum(prices)
        Float.round(total / length(prices), 2)
    end
  end

  defp calculate_price_range(products) do
    prices =
      products
      |> Enum.map(& &1.price)
      |> Enum.reject(&is_nil/1)

    case prices do
      [] ->
        %{min: 0.0, max: 0.0}

      prices ->
        %{
          min: Enum.min(prices),
          max: Enum.max(prices)
        }
    end
  end

  defp find_most_expensive(products) do
    products
    |> Enum.max_by(fn product -> product.price || 0.0 end, fn -> nil end)
    |> case do
      nil ->
        nil

      product ->
        %{
          name: product.name,
          price: product.price,
          category: product.category
        }
    end
  end

  # ============================================================================
  # Private Functions - Category Analysis
  # ============================================================================

  defp group_by_category(products) do
    products
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, category_products} ->
      total_value =
        category_products
        |> Enum.map(fn p -> (p.price || 0.0) * (p.stock || 0) end)
        |> Enum.sum()
        |> Float.round(2)

      %{
        category: category,
        product_count: length(category_products),
        total_stock: Enum.sum(Enum.map(category_products, & &1.stock || 0)),
        total_value: total_value
      }
    end)
    |> Enum.sort_by(& &1.total_value, :desc)
  end

  # ============================================================================
  # Private Functions - Supplier Analysis
  # ============================================================================

  defp find_top_suppliers(products, top_n) do
    products
    |> Enum.group_by(& &1.supplier)
    |> Enum.map(fn {supplier, supplier_products} ->
      %{
        supplier: supplier,
        product_count: length(supplier_products),
        total_stock: Enum.sum(Enum.map(supplier_products, & &1.stock || 0))
      }
    end)
    |> Enum.sort_by(& &1.product_count, :desc)
    |> Enum.take(top_n)
  end
end
