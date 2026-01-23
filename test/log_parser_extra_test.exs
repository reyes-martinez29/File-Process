defmodule FProcess.LogParserExtraTest do
  use ExUnit.Case, async: true

  alias FProcess.Parsers.LogParser

  defp tmp_path(suffix), do: Path.join(System.tmp_dir!(), "fproc_log_#{:erlang.system_time()}_#{suffix}")

  test "empty log returns error" do
    path = tmp_path("empty.log")
    File.write!(path, "")
    assert {:error, _} = LogParser.parse(path)
    File.rm(path)
  end

  test "invalid format line yields partial when mixed with valid lines" do
    path = tmp_path("partial.log")
    File.write!(path, "2021-01-01 12:00:00 [INFO] [svc] OK\nthis line is bad\n2021-01-01 12:01:00 [ERROR] [svc] Fail")
    assert {:partial, entries, errors} = LogParser.parse(path)
    assert length(entries) == 2
    assert length(errors) == 1
    File.rm(path)
  end

  test "invalid hour in line results in error when no valid entries" do
    path = tmp_path("bad_hour.log")
    File.write!(path, "2021-01-01 99:00:00 [INFO] [svc] BadHour")
    assert {:error, _} = LogParser.parse(path)
    File.rm(path)
  end

  test "line that doesn't match format reports error" do
    path = tmp_path("random.log")
    File.write!(path, "just some text")
    assert {:error, _} = LogParser.parse(path)
    File.rm(path)
  end

  test "valid log parses to entries" do
    path = tmp_path("valid.log")
    File.write!(path, "2021-01-01 01:02:03 [ERROR] [comp] Boom")
    assert {:ok, entries} = LogParser.parse(path)
    assert length(entries) == 1
    File.rm(path)
  end

  test "invalid level is rejected" do
    path = tmp_path("bad_level.log")
    File.write!(path, "2021-01-01 01:02:03 [UNKNOWN] [comp] Msg")
    assert {:error, _} = LogParser.parse(path)
    File.rm(path)
  end
end
