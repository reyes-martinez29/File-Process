# Especificación del Proyecto: Procesador Paralelo de Archivos

## 1. Descripción General

### 1.1 Objetivo
Desarrollar un sistema en Elixir que procese múltiples archivos de diferentes formatos (CSV, JSON, LOG) de manera paralela, extrayendo métricas específicas de cada tipo y generando un reporte unificado.

### 1.2 Alcance
- Procesamiento concurrente de archivos usando procesos de Elixir
- Soporte para tres formatos: CSV, JSON y archivos de log
- Generación de reportes con métricas consolidadas
- Manejo de errores y recuperación ante fallos
- Comparación de rendimiento entre procesamiento secuencial y paralelo

### 1.3 Requisitos Previos
- Conocimiento básico de Elixir (40 horas de formación)
- Comprensión de procesos y el BEAM
- No se requiere conocimiento de OTP o Phoenix


### 2 Flujo de Procesamiento

1. **Descubrimiento de archivos**: Identificar todos los archivos en el directorio de entrada
2. **Clasificación**: Determinar el tipo de cada archivo por su extensión
3. **Spawning de procesos**: Crear un proceso worker para cada archivo
4. **Procesamiento paralelo**: Cada worker procesa su archivo asignado
5. **Recolección de resultados**: El proceso coordinador recibe los resultados
6. **Generación de reporte**: Consolidar métricas y crear reporte final
7. **Almacenamiento**: Guardar el reporte en un archivo

## 3. Especificación de Formatos de Archivo

### 3.1 Archivos CSV - Datos de Ventas

**Estructura esperada:**
```csv
fecha,producto,categoria,precio_unitario,cantidad,descuento
YYYY-MM-DD,string,string,float,integer,float
```

**Métricas a extraer:**
- Total de ventas (precio * cantidad - descuento)
- Cantidad de productos únicos vendidos
- Producto más vendido (por cantidad)
- Categoría con mayor ingreso
- Promedio de descuento aplicado
- Rango de fechas procesadas

**Validaciones:**
- Verificar formato de fecha válido
- Precios y cantidades deben ser positivos
- Descuentos entre 0 y 100%

### 3.2 Archivos JSON - Datos de Usuarios

**Estructura esperada:**
```json
{
  "timestamp": "ISO-8601",
  "usuarios": [
    {
      "id": integer,
      "nombre": string,
      "email": string,
      "activo": boolean,
      "ultimo_acceso": "ISO-8601"
    }
  ],
  "sesiones": [
    {
      "usuario_id": integer,
      "inicio": "ISO-8601",
      "duracion_segundos": integer,
      "paginas_visitadas": integer,
      "acciones": [string]
    }
  ]
}
```

**Métricas a extraer:**
- Total de usuarios registrados
- Usuarios activos vs inactivos
- Promedio de duración de sesión
- Total de páginas visitadas
- Top 5 acciones más comunes
- Hora pico de actividad

### 3.3 Archivos LOG - Registros del Sistema

**Formato esperado:**
```
YYYY-MM-DD HH:MM:SS [NIVEL] [COMPONENTE] Mensaje de log
```

**Niveles:** DEBUG, INFO, WARN, ERROR, FATAL

**Métricas a extraer:**
- Distribución de logs por nivel
- Errores más frecuentes (análisis de mensajes)
- Componentes con más errores
- Distribución temporal (logs por hora)
- Tiempo entre errores críticos
- Patrones de error recurrentes

## 4. Entregas

### Entrega 1: Procesamiento Secuencial 

**Objetivos:**
- Implementar lectura de archivos
- Crear parsers básicos para cada formato
- Procesamiento secuencial simple
- Generación de reporte básico

**Criterios de aceptación:**
- [ ] Lee correctamente los tres tipos de archivo
- [ ] Extrae al menos 3 métricas por tipo de archivo
- [ ] Genera un reporte legible en texto plano
- [ ] Maneja archivos no encontrados

### Entrega 2: Procesamiento Paralelo 

**Objetivos:**
- Implementar spawning de procesos workers
- Crear coordinador de procesos
- Implementar recolección de resultados
- Agregar indicador de progreso

**Criterios de aceptación:**
- [ ] Procesa múltiples archivos en paralelo
- [ ] Muestra progreso en tiempo real
- [ ] Recolecta todos los resultados correctamente
- [ ] Mejora de rendimiento medible vs secuencial

### Entrega 3: Manejo de Errores 

**Objetivos:**
- Implementar timeouts para procesos
- Manejar archivos corruptos
- Implementar reintentos para fallos
- Logging de errores

**Criterios de aceptación:**
- [ ] Timeout configurable por proceso
- [ ] Reintento automático en caso de fallo
- [ ] Reporte incluye archivos que fallaron
- [ ] Log detallado de errores

## 5. Estructura del Reporte Final

### 5.1 Formato del Reporte

```
================================================================================
                    REPORTE DE PROCESAMIENTO DE ARCHIVOS
================================================================================

Fecha de generación: YYYY-MM-DD HH:MM:SS
Directorio procesado: /ruta/al/directorio
Modo de procesamiento: [Paralelo/Secuencial]

--------------------------------------------------------------------------------
RESUMEN EJECUTIVO
--------------------------------------------------------------------------------
Total de archivos procesados: XX
  - Archivos CSV: XX
  - Archivos JSON: XX
  - Archivos LOG: XX
  
Tiempo total de procesamiento: XX.XX segundos
Archivos con errores: XX
Tasa de éxito: XX.X%

--------------------------------------------------------------------------------
MÉTRICAS DE ARCHIVOS CSV
--------------------------------------------------------------------------------
[Archivo: ventas_enero.csv]
  * Total de ventas: $XX,XXX.XX
  * Productos únicos: XX
  * Producto más vendido: XXXXX (XX unidades)
  * Categoría top: XXXXX ($XX,XXX.XX)
  * Descuento promedio: XX.X%
  * Período: YYYY-MM-DD a YYYY-MM-DD

[Archivo: ventas_febrero.csv]
  * [Métricas similares...]

Totales Consolidados CSV:
  - Ventas totales: $XXX,XXX.XX
  - Productos únicos totales: XXX

--------------------------------------------------------------------------------
MÉTRICAS DE ARCHIVOS JSON
--------------------------------------------------------------------------------
[Archivo: usuarios.json]
  * Usuarios registrados: XXX
  * Usuarios activos: XXX (XX.X%)
  * Duración promedio de sesión: XX minutos
  * Páginas visitadas totales: X,XXX
  * Top acciones: 
    1. accion_1 (XXX veces)
    2. accion_2 (XXX veces)
    3. accion_3 (XXX veces)

[Archivo: sesiones.json]
  * [Métricas similares...]

--------------------------------------------------------------------------------
MÉTRICAS DE ARCHIVOS LOG
--------------------------------------------------------------------------------
[Archivo: sistema.log]
  * Total de entradas: X,XXX
  * Distribución por nivel:
    - DEBUG: XXX (XX.X%)
    - INFO: XXX (XX.X%)
    - WARN: XXX (XX.X%)
    - ERROR: XXX (XX.X%)
    - FATAL: XXX (XX.X%)
  * Componente más problemático: XXXXX (XX errores)
  * Patrón de error frecuente: "XXXXX" (XX ocurrencias)

[Archivo: aplicacion.log]
  * [Métricas similares...]

--------------------------------------------------------------------------------
ANÁLISIS DE RENDIMIENTO
--------------------------------------------------------------------------------
Comparación Secuencial vs Paralelo:
  * Tiempo secuencial: XX.XX segundos
  * Tiempo paralelo: XX.XX segundos
  * Factor de mejora: X.XX veces más rápido
  * Procesos utilizados: XX
  * Memoria máxima: XX MB

--------------------------------------------------------------------------------
ERRORES Y ADVERTENCIAS
--------------------------------------------------------------------------------
[Si hay errores]
✗ archivo_corrupto.csv: Error al parsear línea 45
✗ datos_invalidos.json: JSON malformado
⚠ archivo_grande.log: Procesado parcialmente (timeout)

================================================================================
                           FIN DEL REPORTE
================================================================================
```

## 6. Requisitos de Entrega

### 6.1 Código Fuente
- Código documentado con comentarios en inglés
- Nombres de variables y funciones en inglés 
- Uso de pattern matching donde sea apropiado
- Uso de bibliotecas externas para json y csv.

### 6.2 Documentación
- README.md con instrucciones de uso
- Ejemplos de ejecución
- Explicación de decisiones de diseño

### 6.3 Pruebas
- Suite de pruebas básicas
- Casos de prueba para archivos válidos e inválidos
- Pruebas de rendimiento documentadas
- Comparación de tiempos secuencial vs paralelo

## 7. Criterios de Evaluación

### 7.1 Funcionalidad (40%)
- Correcta lectura y parsing de archivos
- Precisión en el cálculo de métricas
- Generación exitosa del reporte
- Manejo adecuado de errores

### 7.2 Concurrencia (30%)
- Uso apropiado de spawn y procesos
- Comunicación efectiva entre procesos
- Mejora demostrable de rendimiento
- Coordinación sin condiciones de carrera

### 7.3 Calidad del Código (20%)
- Claridad y organización
- Uso de pattern matching
- Manejo de errores
- Reutilización de código

### 7.4 Documentación y Pruebas (10%)
- Documentación clara
- Pruebas comprehensivas
- Análisis de rendimiento
- Instrucciones de uso

## 8. Recursos y Referencias

### 8.1 Funciones de Elixir útiles
- `spawn/1`, `spawn/3`
- `send/2`, `receive`
- `Process.monitor/1`, `Process.alive?/1`
- `File.read!/1`, `File.write!/2`, `File.stream!/1`
- `String.split/2`, `Enum.*`, `Map.*`
- `Regex.run/2`, `Regex.scan/2`
- Pattern matching y guards

### 8.2 Material de Apoyo
- Documentación oficial de Elixir: https://elixir-lang.org/docs.html
- Guía de procesos: https://elixir-lang.org/getting-started/processes.html
- Pattern matching: https://elixir-lang.org/getting-started/pattern-matching.html

## 9. Ejemplos de referencia

### 9.1 Ejecución básica
```elixir
# Procesar un directorio completo
ProcesadorArchivos.procesar_directorio("./data")
# => {:ok, "Reporte guardado en output/reporte_final.txt"}

# Procesar archivos específicos
archivos = ["data/ventas_enero.csv", "data/usuarios.json"]
ProcesadorArchivos.procesar_archivos(archivos)
# => {:ok, %{csv: [...], json: [...]}}
```

### 9.2 Ejecución con Opciones
```elixir
# Con límite de workers
opciones = %{max_workers: 5, timeout: 10_000}
ProcesadorArchivos.procesar_con_opciones("./data", opciones)

# Modo benchmark
ProcesadorArchivos.benchmark_paralelo_vs_secuencial("./data")
# => 
# Secuencial: 4523ms
# Paralelo: 892ms  
# Mejora: 5.07x
```

## 10. Desafíos Opcionales (Extra)

Para estudiantes que terminen antes:

1. **Formato adicional**: Agregar soporte para XML
2. **Compresión**: Procesar archivos .gz directamente
3. **Caché de resultados**: Evitar reprocesar archivos no modificados

---

**Fechas de entrega**: Propuestas por el estudiante. 
**Modalidad**: Individual
**Consultas**: Durante horario de clase o por el canal de Discord del curso
