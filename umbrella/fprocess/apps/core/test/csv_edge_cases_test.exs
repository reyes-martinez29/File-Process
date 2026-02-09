defmodule FProcess.CSVCasesTest do
  use ExUnit.Case, async: true

  alias FProcess.Parsers.CSVParser

  defp tmp_path(suffix) do
    Path.join(System.tmp_dir!(), "fprocess_test_#{:erlang.system_time()}_#{suffix}")
  end

  test "empty csv file returns error" do
    path = tmp_path("empty.csv")
    File.write!(path, "")
    assert {:error, msg} = CSVParser.parse(path)
    assert String.contains?(msg, "Empty file")
    File.rm(path)
  end

  test "invalid header returns error" do
    path = tmp_path("bad_header.csv")
    File.write!(path, "foo,bar\n1,2")
    assert {:error, msg} = CSVParser.parse(path)
    assert String.contains?(msg, "Invalid CSV header")
    File.rm(path)
  end

  test "invalid date in row returns error" do
    path = tmp_path("bad_date.csv")
    File.write!(path, "fecha,producto,categoria,precio_unitario,cantidad,descuento\nnot-a-date,Prod,Cat,10.0,1,0")
    assert {:error, _} = CSVParser.parse(path)
    File.rm(path)
  end

  test "negative price returns error" do
    path = tmp_path("neg_price.csv")
    File.write!(path, "fecha,producto,categoria,precio_unitario,cantidad,descuento\n2020-01-01,Prod,Cat,-5.0,1,0")
    assert {:error, _} = CSVParser.parse(path)
    File.rm(path)
  end

  test "discount > 100 returns error" do
    path = tmp_path("bad_discount.csv")
    File.write!(path, "fecha,producto,categoria,precio_unitario,cantidad,descuento\n2020-01-01,Prod,Cat,10.0,1,150")
    assert {:error, _} = CSVParser.parse(path)
    File.rm(path)
  end

  test "invalid field count returns error" do
    path = tmp_path("bad_fields.csv")
    File.write!(path, "fecha,producto,categoria,precio_unitario,cantidad,descuento\n1,2,3")
    assert {:error, _} = CSVParser.parse(path)
    File.rm(path)
  end
end
