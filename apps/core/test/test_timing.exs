# Agregar timestamps para ver cuándo se ejecuta Progress

Code.compile_file("lib/f_process.ex")
Code.require_file("lib/structs.ex")

files = [
  {:csv, "data/valid/ventas_enero.csv"},
  {:json, "data/valid/usuarios.json"},
  {:xml, "data/valid/productos.xml"}
]

config = %{
  max_retries: 1,
  timeout: 5000,
  show_progress: true
}

IO.puts("=== PARALLEL ===")
start = System.monotonic_time(:millisecond)
FProcess.Modes.Parallel.run(files, config)
elapsed = System.monotonic_time(:millisecond) - start
IO.puts("\nParallel total: #{elapsed}ms\n")

IO.puts("=== SEQUENTIAL ===")
start = System.monotonic_time(:millisecond)
FProcess.Modes.Sequential.run(files, config)
elapsed = System.monotonic_time(:millisecond) - start
IO.puts("\nSequential total: #{elapsed}ms")
