defmodule FProcess.CSVParserTest do
  use ExUnit.Case, async: true

  alias FProcess.Parsers.CSVParser

  test "parses valid ventas_enero.csv" do
    assert {:ok, sales} = CSVParser.parse("data/valid/ventas_enero.csv")
    assert length(sales) == 30
    assert Enum.all?(sales, fn s -> is_struct(s) or is_map(s) end)
  end

  test "returns error for corrupt csv" do
    assert {:error, _} = CSVParser.parse("data/error/ventas_corrupto.csv")
  end
end
