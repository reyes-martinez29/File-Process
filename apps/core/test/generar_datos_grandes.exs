# Script para generar archivos de prueba más grandes

# Generar CSV grande (10,000 filas)
csv_content = """
fecha,producto,categoria,precio_unitario,cantidad,descuento
"""

productos = ["Laptop", "Mouse", "Teclado", "Monitor", "Webcam", "Auriculares", "USB", "SSD", "RAM", "GPU"]
categorias = ["Computadoras", "Accesorios", "Componentes", "Audio", "Video"]

Enum.each(1..10_000, fn i ->
  fecha = "2024-#{:rand.uniform(12) |> to_string() |> String.pad_leading(2, "0")}-#{:rand.uniform(28) |> to_string() |> String.pad_leading(2, "0")}"
  producto = Enum.random(productos)
  categoria = Enum.random(categorias)
  precio = :rand.uniform(10000) / 10
  cantidad = :rand.uniform(100)
  descuento = :rand.uniform(30)
  
  csv_content = csv_content <> "#{fecha},#{producto},#{categoria},#{precio},#{cantidad},#{descuento}\n"
end)

File.write!("data/valid/ventas_grandes.csv", csv_content)
IO.puts("✓ Generado: ventas_grandes.csv (#{byte_size(csv_content)} bytes)")

# Generar JSON grande
usuarios = Enum.map(1..1000, fn i ->
  %{
    "id" => i,
    "nombre" => "Usuario#{i}",
    "email" => "user#{i}@example.com",
    "activo" => :rand.uniform(10) > 2,
    "ultimo_acceso" => "2024-01-#{:rand.uniform(28) |> to_string() |> String.pad_leading(2, "0")}T#{:rand.uniform(24)-1 |> to_string() |> String.pad_leading(2, "0")}:00:00Z"
  }
end)

sesiones = Enum.flat_map(1..1000, fn user_id ->
  Enum.map(1..:rand.uniform(20), fn _ ->
    %{
      "usuario_id" => user_id,
      "inicio" => "2024-01-#{:rand.uniform(28) |> to_string() |> String.pad_leading(2, "0")}T#{:rand.uniform(24)-1 |> to_string() |> String.pad_leading(2, "0")}:00:00Z",
      "duracion_segundos" => :rand.uniform(7200),
      "paginas_visitadas" => :rand.uniform(50),
      "acciones" => Enum.take_random(["click", "scroll", "submit", "download", "upload"], :rand.uniform(5))
    }
  end)
end)

json_data = %{
  "timestamp" => "2024-01-01T00:00:00Z",
  "usuarios" => usuarios,
  "sesiones" => sesiones
}

json_content = Jason.encode!(json_data, pretty: true)
File.write!("data/valid/usuarios_grandes.json", json_content)
IO.puts("✓ Generado: usuarios_grandes.json (#{byte_size(json_content)} bytes)")

# Generar LOG grande
log_content = Enum.map(1..50_000, fn i ->
  fecha = "2024-01-#{:rand.uniform(28) |> to_string() |> String.pad_leading(2, "0")} #{:rand.uniform(24)-1 |> to_string() |> String.pad_leading(2, "0")}:#{:rand.uniform(60)-1 |> to_string() |> String.pad_leading(2, "0")}:#{:rand.uniform(60)-1 |> to_string() |> String.pad_leading(2, "0")}"
  nivel = Enum.random(["DEBUG", "INFO", "INFO", "INFO", "WARN", "ERROR", "FATAL"])
  componente = Enum.random(["Database", "API", "Auth", "Cache", "Queue"])
  mensaje = Enum.random([
    "Request processed successfully",
    "Connection established",
    "Query executed in 45ms",
    "Cache miss for key: user_123",
    "Failed to connect to database",
    "Timeout waiting for response",
    "Invalid authentication token",
    "Resource not found"
  ])
  
  "#{fecha} [#{nivel}] [#{componente}] #{mensaje}"
end)
|> Enum.join("\n")

File.write!("data/valid/sistema_grande.log", log_content)
IO.puts("✓ Generado: sistema_grande.log (#{byte_size(log_content)} bytes)")

IO.puts("\n📊 Archivos generados:")
IO.puts("- CSV:  ~#{round(byte_size(csv_content)/1024)}KB")
IO.puts("- JSON: ~#{round(byte_size(json_content)/1024)}KB") 
IO.puts("- LOG:  ~#{round(byte_size(log_content)/1024)}KB")
