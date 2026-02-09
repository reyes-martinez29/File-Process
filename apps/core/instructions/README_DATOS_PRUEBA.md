# Archivos de Prueba para el Procesador Paralelo

## Estructura de Archivos

### Archivos Válidos

1. **ventas_enero.csv** (30 registros)
   - Datos de ventas del mes de enero 2024
   - Contiene: fecha, producto, categoría, precio_unitario, cantidad, descuento
   - Todos los datos son válidos y bien formateados

2. **ventas_febrero.csv** (30 registros)
   - Datos de ventas del mes de febrero 2024
   - Estructura idéntica a ventas_enero.csv
   - Datos válidos para comparación mensual

3. **usuarios.json** (10 usuarios, 10 sesiones)
   - Información de usuarios y sus sesiones
   - Incluye usuarios activos e inactivos
   - Sesiones con métricas de uso completas

4. **sesiones.json** (8 usuarios, 12 sesiones)
   - Datos adicionales de sesiones de usuarios
   - Para probar agregación de múltiples archivos JSON
   - Incluye diferentes patrones de uso

5. **sistema.log** (70 líneas)
   - Logs del sistema del 28 de febrero 2024
   - Incluye todos los niveles: DEBUG, INFO, WARN, ERROR, FATAL
   - Formato: fecha hora [NIVEL] [COMPONENTE] mensaje

6. **aplicacion.log** (65 líneas)
   - Logs de aplicación del 28 de febrero 2024
   - Enfocado en eventos de usuario y aplicación
   - Mismo formato que sistema.log

### Archivos para Pruebas de Error

7. **ventas_corrupto.csv** (11 líneas con errores)
   - Contiene múltiples tipos de errores:
     * Precio con texto "ERROR"
     * Cantidad vacía
     * Cantidad con texto "abc"
     * Línea incompleta (solo 2 campos)
     * Precio negativo
     * Descuento mayor a 100%
     * Descuento negativo
     * Línea de texto sin formato CSV
     * Campos vacíos

8. **usuarios_malformado.json**
   - JSON mal formateado con:
     * Comillas faltantes
     * Comas faltantes
     * Tipos de datos incorrectos
     * Valores inválidos (duracion_segundos negativa)
     * Comentarios no válidos en JSON
     * Llaves sin comillas

## Uso en el Proyecto

### Organización Recomendada
```
proyecto/
├── lib/
│   └── [código del proyecto]
├── data/
│   ├── valid/
│   │   ├── ventas_enero.csv
│   │   ├── ventas_febrero.csv
│   │   ├── usuarios.json
│   │   ├── sesiones.json
│   │   ├── sistema.log
│   │   └── aplicacion.log
│   └── error/
│       ├── ventas_corrupto.csv
│       └── usuarios_malformado.json
└── output/
    └── [reportes generados]
```

### Casos de Prueba Sugeridos

#### 1. Procesamiento Básico
```elixir
# Procesar un solo archivo válido
ProcesadorArchivos.procesar_archivo("data/valid/ventas_enero.csv")

# Resultado esperado:
%{
  total_ventas: 45823.45,  # ejemplo
  productos_unicos: 15,
  producto_mas_vendido: "Cable HDMI",
  categoria_top: "Computadoras",
  descuento_promedio: 12.5,
  rango_fechas: {"2024-01-02", "2024-01-30"}
}
```

#### 2. Procesamiento Paralelo
```elixir
# Procesar todos los archivos válidos
archivos = File.ls!("data/valid")
|> Enum.map(&Path.join("data/valid", &1))

ProcesadorArchivos.procesar_paralelo(archivos)
```

#### 3. Manejo de Errores
```elixir
# Procesar archivo corrupto
ProcesadorArchivos.procesar_con_manejo_errores("data/error/ventas_corrupto.csv")

# Resultado esperado:
%{
  estado: :parcial,
  lineas_procesadas: 7,
  lineas_con_error: 4,
  errores: [
    {3, "Precio inválido: ERROR"},
    {4, "Cantidad vacía"},
    {5, "Cantidad no numérica: abc"},
    {6, "Línea incompleta"}
  ]
}
```

#### 4. Benchmark
```elixir
# Comparar rendimiento
ProcesadorArchivos.benchmark do
  archivos = ["ventas_enero.csv", "ventas_febrero.csv", 
              "usuarios.json", "sesiones.json",
              "sistema.log", "aplicacion.log"]
  
  tiempo_secuencial = medir_tiempo(fn ->
    Enum.map(archivos, &procesar_archivo/1)
  end)
  
  tiempo_paralelo = medir_tiempo(fn ->
    procesar_paralelo(archivos)
  end)
  
  IO.puts("Mejora: #{tiempo_secuencial / tiempo_paralelo}x")
end
```

## Métricas Esperadas

### Archivos CSV
- **Total de registros**: 60 (válidos)
- **Productos únicos**: ~20-25
- **Rango de precios**: $14.99 - $1,499.99
- **Categorías**: 7 (Computadoras, Accesorios, Monitores, etc.)

### Archivos JSON  
- **Total usuarios**: 18
- **Usuarios activos**: ~13-14
- **Total sesiones**: 22
- **Duración promedio sesión**: ~1,500 segundos

### Archivos LOG
- **Total entradas**: 135
- **Distribución de niveles**:
  * INFO: ~60%
  * DEBUG: ~15%
  * WARN: ~10%
  * ERROR: ~12%
  * FATAL: ~3%

## Validaciones Importantes

1. **CSV**: Verificar que precio y cantidad sean números positivos
2. **JSON**: Validar estructura antes de procesar
3. **LOG**: Manejar líneas que no coincidan con el patrón esperado
4. **General**: Implementar timeouts para archivos grandes

## Notas para Estudiantes

- Los archivos están diseñados para ser procesados en menos de 1 segundo cada uno
- El procesamiento paralelo debería mostrar mejora significativa (3-5x)
- Los archivos con errores son para probar robustez del código
- Se recomienda implementar logging detallado durante el desarrollo
- Considerar el uso de `Flow` o `Task` para paralelización avanzada (opcional)

## Extensiones Sugeridas

1. Agregar más tipos de archivo (XML, YAML)
2. Implementar compresión/descompresión
3. Crear generador de archivos de prueba aleatorios
4. Añadir validación de esquemas
5. Implementar caché de resultados