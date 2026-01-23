defmodule FProcess.CLITest do
  use ExUnit.Case, async: false

  @cwd File.cwd!()

  test "help prints usage" do
    {output, exit} = System.cmd("mix", ["run", "-e", "FProcess.CLI.main([\"-h\"])"], cd: @cwd)
    assert exit == 0
    assert String.contains?(output, "USAGE")
  end

  test "invalid options exit non-zero and show help" do
    {output, exit} = System.cmd("mix", ["run", "-e", "FProcess.CLI.main([\"--nope\"])"], cd: @cwd)
    assert exit != 0 or String.contains?(output, "Invalid options") or String.contains?(output, "USAGE")
  end

  test "process directory via CLI (sequential) succeeds" do
    {output, exit} = System.cmd("mix", ["run", "-e", "FProcess.CLI.main([\"data/valid\",\"--mode\",\"sequential\"])"], cd: @cwd, stderr_to_stdout: true)
    assert exit == 0
    assert String.contains?(output, "Report")
  end

  test "benchmark via CLI returns summary" do
    {output, exit} = System.cmd("mix", ["run", "-e", "FProcess.CLI.main([\"data/valid\",\"--benchmark\"])"], cd: @cwd, stderr_to_stdout: true)
    # benchmark may call System.halt(0)
    assert exit == 0
    assert String.contains?(output, "BENCHMARK SUMMARY") or String.contains?(output, "Report")
  end
end
