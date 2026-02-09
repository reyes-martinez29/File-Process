defmodule FProcessTest do
  use ExUnit.Case, async: false

  alias FProcess.Parsers.{CSVParser, JSONParser, LogParser, XMLParser}
  alias FProcess.Metrics.{CSVMetrics, LogMetrics}
  alias FProcess.FileProcessor

  describe "basic helpers" do
  end

  describe "CSVParser" do
    test "parses valid ventas_enero.csv" do
      assert {:ok, sales} = CSVParser.parse("data/valid/ventas_enero.csv")
      assert length(sales) == 30
    end

    test "errors on corrupt csv" do
      assert {:error, _} = CSVParser.parse("data/error/ventas_corrupto.csv")
    end
  end

  describe "CSVMetrics" do
    setup do
      {:ok, sales} = CSVParser.parse("data/valid/ventas_enero.csv")
      %{sales: sales}
    end

    test "calculates totals and stats", %{sales: sales} do
      assert {:ok, metrics} = CSVMetrics.calculate(sales)
      assert metrics.total_records == 30
      assert_in_delta metrics.total_sales, 24399.93, 2.0
      assert metrics.unique_products > 0
      assert metrics.total_quantity == 171
      assert is_map(metrics.date_range)
    end
  end

  describe "JSONParser" do
    test "parses valid usuarios.json" do
      assert {:ok, data} = JSONParser.parse("data/valid/usuarios.json")
      assert is_map(data)
      assert Map.has_key?(data, :users)
    end

    test "returns error for malformed json" do
      assert {:error, _} = JSONParser.parse("data/error/usuarios_malformado.json")
    end
  end

  describe "LogParser and LogMetrics" do
    test "parses sistema.log and computes metrics" do
      assert {:ok, entries} = LogParser.parse("data/valid/sistema.log")
      assert length(entries) > 0
      assert {:ok, metrics} = LogMetrics.calculate(entries)
      assert metrics.total_entries == length(entries)
      assert Map.has_key?(metrics.level_distribution, "ERROR")
    end
  end

  describe "XMLParser" do
    test "parses productos.xml and returns product list" do
      assert {:ok, xml} = XMLParser.parse("data/valid/productos.xml")
      assert is_map(xml)
      assert xml.total_products > 0
      assert is_list(xml.products)
    end
  end

  describe "FileProcessor integration" do
    test "processes a single CSV file and returns FileResult" do
      result = FileProcessor.process({:csv, "data/valid/ventas_enero.csv"}, %{})
      assert result.status == :ok
      assert is_map(result.metrics)
      assert result.metrics.total_records == 30
    end
  end

  describe "FProcess end-to-end" do
    test "process directory returns execution report" do
      assert {:ok, report} = FProcess.process("data/valid", mode: :sequential)
      assert is_map(report)
      assert report.total_files > 0
      assert is_list(report.results)
    end
  end
end
