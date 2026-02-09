#!/usr/bin/env elixir

# Test para medir el overhead de Progress.update

defmodule ProgressTest do
  def test_progress_overhead(iterations) do
    # Simular Progress sin IO
    start = System.monotonic_time(:millisecond)
    Enum.each(1..iterations, fn i ->
      _percentage = i / iterations
      _filled = round(_percentage * 40)
      _empty = 40 - _filled
      # No hacer IO
    end)
    end_time = System.monotonic_time(:millisecond)
    without_io = end_time - start

    # Con IO real (como Progress.update)
    start = System.monotonic_time(:millisecond)
    Enum.each(1..iterations, fn i ->
      percentage = i / iterations
      filled = round(percentage * 40)
      empty = 40 - filled
      filled_bar = String.duplicate("█", filled)
      empty_bar = String.duplicate("░", empty)
      IO.write("\r[#{filled_bar}#{empty_bar}] #{Float.round(percentage * 100, 1)}%")
    end)
    end_time = System.monotonic_time(:millisecond)
    with_io = end_time - start

    IO.write("\n")
    IO.puts("Progress overhead test (#{iterations} iterations):")
    IO.puts("  Without IO: #{without_io}ms")
    IO.puts("  With IO:    #{with_io}ms")
    IO.puts("  Overhead:   #{with_io - without_io}ms")
    IO.puts("  Per call:   #{Float.round((with_io - without_io) / iterations, 2)}ms")
  end
end

ProgressTest.test_progress_overhead(7)
IO.puts("")
ProgressTest.test_progress_overhead(100)
