# Test script to run FProcess
IO.puts("Testing FProcess with valid data...")
result = FProcess.process("data/valid")

case result do
  {:ok, report} ->
    IO.puts("\n✅ SUCCESS!")
    IO.puts("Files processed: #{report.total_files}")
    IO.puts("Successful: #{report.successful}")
    IO.puts("Failed: #{report.failed}")
    IO.puts("Duration: #{report.duration_ms}ms")

  {:error, reason} ->
    IO.puts("\n❌ ERROR: #{reason}")
end
