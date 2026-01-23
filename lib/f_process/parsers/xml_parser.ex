defmodule FProcess.Parsers.XMLParser do
  @moduledoc """
  Parser for XML product catalog files.

  Expected structure:
  <catalog>
    <metadata>
      <generated>ISO-8601</generated>
      <source>string</source>
    </metadata>
    <products>
      <product id="...">
        <name>string</name>
        <category>string</category>
        <price currency="...">float</price>
        <stock>integer</stock>
        <supplier>string</supplier>
      </product>
      ...
    </products>
  </catalog>

  This is a flexible parser that can be adapted to other XML structures.
  """

  import SweetXml

  @doc """
  Parse an XML file and return structured data.

  Returns:
  - `{:ok, %{metadata: ..., products: [...]}}` - Success
  - `{:error, reason}` - Failed to parse
  """
  @spec parse(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        parse_xml_content(content)

      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  # ============================================================================
  # Private Functions - Parsing
  # ============================================================================

  defp parse_xml_content(content) do
    try do
      data = parse_catalog(content)
      {:ok, data}
    rescue
      e in SweetXml.XmerlFatal ->
        {:error, "XML parsing error: #{Exception.message(e)}"}

      e ->
        {:error, "Unexpected error: #{Exception.message(e)}"}
    end
  end

  defp parse_catalog(xml_content) do
    doc = SweetXml.parse(xml_content)

    metadata = extract_metadata(doc)
    products = extract_products(doc)

    %{
      metadata: metadata,
      products: products,
      total_products: length(products),
      total_stock: calculate_total_stock(products),
      categories: extract_categories(products)
    }
  end

  # ============================================================================
  # Private Functions - Metadata Extraction
  # ============================================================================

  defp extract_metadata(doc) do
    generated = doc
      |> xpath(~x"//metadata/generated/text()"s)
      |> case do
        "" -> nil
        value -> value
      end

    source = doc
      |> xpath(~x"//metadata/source/text()"s)
      |> case do
        "" -> nil
        value -> value
      end

    %{
      generated: generated,
      source: source
    }
  end

  # ============================================================================
  # Private Functions - Products Extraction
  # ============================================================================

  defp extract_products(doc) do
    doc
    |> xpath(
      ~x"//products/product"l,
      id: ~x"./@id"s,
      name: ~x"./name/text()"s,
      category: ~x"./category/text()"s,
      price: ~x"./price/text()"f,
      currency: ~x"./price/@currency"s,
      stock: ~x"./stock/text()"i,
      supplier: ~x"./supplier/text()"s
    )
    |> Enum.map(&normalize_product/1)
  end

  defp normalize_product(product) do
    %{
      id: product.id,
      name: product.name,
      category: product.category,
      price: product.price,
      currency: if(product.currency == "", do: "USD", else: product.currency),
      stock: product.stock,
      supplier: product.supplier
    }
  end

  # ============================================================================
  # Private Functions - Analysis
  # ============================================================================

  defp calculate_total_stock(products) do
    Enum.reduce(products, 0, fn product, acc ->
      acc + (product.stock || 0)
    end)
  end

  defp extract_categories(products) do
    products
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
