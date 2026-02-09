defmodule FProcess.FileProcessorTest do
  use ExUnit.Case, async: false

  alias FProcess.FileProcessor

  @enero {:csv, "data/valid/ventas_enero.csv"}

  describe "FileProcessor.process/2" do
    test "processes a CSV file and returns FileResult with metrics" do
      result = FileProcessor.process(@enero, %{})
      assert result.status == :ok
      assert is_map(result.metrics)
      assert result.metrics.total_records == 30
      assert_in_delta result.metrics.total_sales, 24399.93, 0.1
    end
  end
end
