defmodule FProcess.JSONEdgeTest do
  use ExUnit.Case, async: true

  alias FProcess.Parsers.JSONParser

  defp tmp_path(suffix), do: Path.join(System.tmp_dir!(), "fproc_json_#{:erlang.system_time()}_#{suffix}")

  test "empty json file returns error" do
    path = tmp_path("empty.json")
    File.write!(path, "")
    assert {:error, _} = JSONParser.parse(path)
    File.rm(path)
  end

  test "missing usuarios field returns error" do
    path = tmp_path("no_users.json")
    File.write!(path, ~s({"sesiones": []}))
    assert {:error, _} = JSONParser.parse(path)
    File.rm(path)
  end

  test "user with invalid id type returns error" do
    path = tmp_path("bad_user.json")
    File.write!(path, ~s({"usuarios":[{"id":"x","nombre":"A","email":"a@x"}], "sesiones": []}))
    assert {:error, _} = JSONParser.parse(path)
    File.rm(path)
  end

  test "sessions acciones not list are normalized" do
    path = tmp_path("sessions_actions.json")
    File.write!(path, ~s({"usuarios":[], "sesiones":[{"usuario_id":1, "acciones":"notalist"}]}))
    assert {:ok, data} = JSONParser.parse(path)
    assert is_list(Map.get(data, :sessions))
    File.rm(path)
  end

  test "malformed json returns error" do
    path = tmp_path("malformed.json")
    File.write!(path, "{not valid json}")
    assert {:error, _} = JSONParser.parse(path)
    File.rm(path)
  end
end
