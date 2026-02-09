defmodule FProcess.Parsers.CSVParser do
  @moduledoc """
  Parser for CSV sales data files.

  Expected structure:
  fecha,producto,categoria,precio_unitario,cantidad,descuento
  YYYY-MM-DD,string,string,float,integer,float

  Validates:
  - Date format (YYYY-MM-DD)
  - Positive prices and quantities
  - Discount between 0 and 100
  """

  alias FProcess.Structs.Sale

  NimbleCSV.define(SalesParser, separator: ",", escape: "\"")

  @required_headers ["fecha", "producto", "categoria", "precio_unitario", "cantidad", "descuento"]

  @doc """
  Parse a CSV file and return a list of Sale structs.

  Returns:
  - `{:ok, sales_list}` - All rows parsed successfully
  - `{:partial, sales_list, errors}` - Some rows failed validation
  - `{:error, reason}` - File could not be read or has invalid structure
  """
  @spec parse(String.t()) ::
    {:ok, list(Sale.t())} |
    {:partial, list(Sale.t()), list({integer(), String.t()})} |
    {:error, String.t()}
  def parse(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        parse_content(content)

      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  # ============================================================================
  # Private Functions - Parsing
  # ============================================================================

  defp parse_content(content) do
    lines = String.split(content, "\n", trim: true)

    case lines do
      [] ->
        {:error, "Empty file"}

      [header | data_lines] ->
        case validate_header(header) do
          :ok ->
            parse_data_lines(data_lines)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp validate_header(header) do
    headers =
      header
      |> String.downcase()
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    if headers == @required_headers do
      :ok
    else
      {:error, "Invalid CSV header. Expected: #{Enum.join(@required_headers, ",")}"}
    end
  end

  defp parse_data_lines(lines) do
    {sales, errors} =
      lines
      |> Enum.with_index(2)  # Start at line 2 (after header)
      |> Enum.reduce({[], []}, fn {line, line_num}, {sales_acc, errors_acc} ->
        case parse_line(line, line_num) do
          {:ok, sale} ->
            {[sale | sales_acc], errors_acc}

          {:error, reason} ->
            {sales_acc, [{line_num, reason} | errors_acc]}
        end
      end)

    # Reverse to maintain original order
    sales = Enum.reverse(sales)
    errors = Enum.reverse(errors)

    cond do
      length(errors) > 0 ->
        # ANY error means the entire file is corrupted
        error_details = errors
          |> Enum.take(3)
          |> Enum.map(fn {line_num, reason} -> "Line #{line_num}: #{reason}" end)
          |> Enum.join("; ")
        {:error, "CSV validation failed: #{error_details}"}

      true ->
        {:ok, sales}
    end
  end

  defp parse_line(line, _line_num) do
    case String.split(line, ",") do
      [fecha, producto, categoria, precio_str, cantidad_str, descuento_str] ->
        build_sale(fecha, producto, categoria, precio_str, cantidad_str, descuento_str)

      _ ->
        {:error, "Invalid CSV format: expected 6 fields"}
    end
  rescue
    e -> {:error, "Parse error: #{Exception.message(e)}"}
  end

  # ============================================================================
  # Private Functions - Validation and Construction
  # ============================================================================

  defp build_sale(fecha, producto, categoria, precio_str, cantidad_str, descuento_str) do
    with {:ok, date} <- parse_date(fecha),
         {:ok, precio} <- parse_float(precio_str, "precio_unitario"),
         {:ok, cantidad} <- parse_integer(cantidad_str, "cantidad"),
         {:ok, descuento} <- parse_float(descuento_str, "descuento"),
         :ok <- validate_positive(precio, "precio_unitario"),
         :ok <- validate_positive(cantidad, "cantidad"),
         :ok <- validate_discount(descuento) do

      # Calculate total: apply discount percentage to line total
      # discount is provided as percentage (e.g., 5.0 for 5%)
      total = precio * cantidad * (1 - descuento / 100)

      sale = %Sale{
        date: date,
        product: String.trim(producto),
        category: String.trim(categoria),
        unit_price: precio,
        quantity: cantidad,
        discount: descuento,
        total: total
      }

      {:ok, sale}
    end
  end

  defp parse_date(date_str) do
    date_str = String.trim(date_str)

    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        {:ok, date}

      {:error, _} ->
        {:error, "Invalid date format '#{date_str}'. Expected: YYYY-MM-DD"}
    end
  end

  defp parse_float(str, field_name) do
    str = String.trim(str)

    case Float.parse(str) do
      {value, ""} ->
        {:ok, value}

      {value, _remainder} ->
        {:ok, value}

      :error ->
        {:error, "Invalid #{field_name}: '#{str}' is not a valid number"}
    end
  end

  defp parse_integer(str, field_name) do
    str = String.trim(str)

    case Integer.parse(str) do
      {value, ""} ->
        {:ok, value}

      {value, _remainder} ->
        {:ok, value}

      :error ->
        {:error, "Invalid #{field_name}: '#{str}' is not a valid integer"}
    end
  end

  defp validate_positive(value, _field_name) when value > 0, do: :ok
  defp validate_positive(value, field_name) do
    {:error, "#{field_name} must be positive, got: #{value}"}
  end

  defp validate_discount(discount) when discount >= 0 and discount <= 100, do: :ok
  defp validate_discount(discount) do
    {:error, "Discount must be between 0 and 100, got: #{discount}"}
  end
end
