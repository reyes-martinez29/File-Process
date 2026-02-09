defmodule FProcess.ParsersAndMetricsTest do
  use ExUnit.Case, async: true

  alias FProcess.Parsers.{JSONParser, LogParser, XMLParser}
  alias FProcess.Metrics.LogMetrics

  test "parses valid usuarios.json" do
    assert {:ok, data} = JSONParser.parse("data/valid/usuarios.json")
    assert is_map(data)
    assert Map.has_key?(data, :users)
    assert Map.has_key?(data, :sessions)
  end

  test "returns error for malformed usuarios json" do
    assert {:error, _} = JSONParser.parse("data/error/usuarios_malformado.json")
  end

  test "parses sistema.log and computes log metrics" do
    assert {:ok, entries} = LogParser.parse("data/valid/sistema.log")
    assert length(entries) > 0
    assert {:ok, metrics} = LogMetrics.calculate(entries)
    assert metrics.total_entries == length(entries)
    assert Map.has_key?(metrics.level_distribution, "ERROR")
  end

  test "parses productos.xml" do
    assert {:ok, xml} = XMLParser.parse("data/valid/productos.xml")
    assert is_map(xml)
    assert xml.total_products > 0
    assert is_list(xml.products)
  end
end
