defmodule FProcess.ModesTest do
  use ExUnit.Case, async: true

  alias FProcess.Modes.{Sequential, Parallel}

  @single [{:csv, "data/valid/ventas_enero.csv"}]
  @multiple [
    {:csv, "data/valid/ventas_enero.csv"},
    {:json, "data/valid/usuarios.json"}
  ]

  test "sequential.run returns list of FileResult" do
    results = Sequential.run(@single, %{show_progress: false})
    assert is_list(results)
    assert length(results) == 1
    res = hd(results)
    assert res.status in [:ok, :error]
  end

  test "sequential.run processes multiple files" do
    results = Sequential.run(@multiple, %{show_progress: false})
    assert is_list(results)
    assert length(results) == 2
  end

  test "parallel.run returns results for single file" do
    results = Parallel.run(@single, %{show_progress: false})
    assert is_list(results)
    assert length(results) == 1
    assert hd(results).status in [:ok, :error]
  end

  test "parallel.run handles multiple files" do
    results = Parallel.run(@multiple, %{show_progress: false})
    assert is_list(results)
    assert length(results) == 2
  end
end
