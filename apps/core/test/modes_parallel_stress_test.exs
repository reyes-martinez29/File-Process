defmodule FProcess.ModesParallelStressTest do
  use ExUnit.Case, async: false

  alias FProcess.Modes.Parallel

  test "parallel mode handles many files" do
    # Create a list of 10 entries using the same small file
    files = for _ <- 1..10, do: {:csv, "data/valid/ventas_febrero.csv"}
    results = Parallel.run(files, %{show_progress: false})
    assert length(results) == 10
    assert Enum.all?(results, fn r -> r.status in [:ok, :error] end)
  end

  test "parallel mode with timeout returns results" do
    files = for _ <- 1..5, do: {:csv, "data/valid/ventas_enero.csv"}
    results = Parallel.run(files, %{show_progress: false, timeout: 1_000})
    assert length(results) == 5
  end
end
