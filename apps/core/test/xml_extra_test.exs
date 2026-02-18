defmodule FProcess.XMLExtraTest do
  use ExUnit.Case, async: true

  alias FProcess.Parsers.XMLParser

  defp tmp_path(suffix), do: Path.join(System.tmp_dir!(), "fproc_xml_#{:erlang.system_time()}_#{suffix}")

  test "empty xml returns error or raises" do
    path = tmp_path("empty.xml")
    File.write!(path, "")
    try do
      res = XMLParser.parse(path)
      assert match?({:error, _}, res)
    catch
      :exit, _ -> assert true
    end
    File.rm(path)
  end

  test "no products yields zero totals" do
    content = """
    <catalog>
      <metadata><generated>2021-01-01</generated></metadata>
      <products></products>
    </catalog>
    """
    path = tmp_path("noproducts.xml")
    File.write!(path, content)
    assert {:ok, data} = XMLParser.parse(path)
    assert data.total_products == 0
    File.rm(path)
  end

  test "malformed xml returns error or raises" do
    path = tmp_path("bad.xml")
    File.write!(path, "<notclosed>")
    try do
      res = XMLParser.parse(path)
      assert match?({:error, _}, res)
    catch
      :exit, _ -> assert true
    end
    File.rm(path)
  end
end
