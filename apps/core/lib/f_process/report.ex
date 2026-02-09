defmodule FProcess.Report do
  @moduledoc """
  Report generation module following the exact specification format.

  Generates a text report matching the structure defined in
  proyecto_procesador_archivos.md section 5.1
  """

  alias FProcess.Structs.{ExecutionReport, FileResult}

  @report_width 80

  @doc """
  Generate and save a report to a file.
  """
  @spec generate_and_save(ExecutionReport.t(), String.t()) ::
    {:ok, String.t()} | {:error, String.t()}
  def generate_and_save(execution_report, output_dir) do
    report_content = generate(execution_report)
    #timestamp = format_timestamp(execution_report.start_time)
    #filename = "reporte_#{timestamp}.txt"
    filename = "reporte_output.txt"
    file_path = Path.join(output_dir, filename)

    File.mkdir_p!(output_dir)

    case File.write(file_path, report_content) do
      :ok -> {:ok, file_path}
      {:error, reason} -> {:error, "Failed to write report: #{inspect(reason)}"}
    end
  end

  @doc """
  Generate report content as a string following specification format.
  """
  @spec generate(ExecutionReport.t()) :: String.t()
  def generate(report) do
    [
      header(),
      metadata_section(report),
      summary_section(report),
      csv_metrics_section(report),
      json_metrics_section(report),
      log_metrics_section(report),
      xml_metrics_section(report),
      performance_section(report),
      errors_section(report),
      footer()
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  # ============================================================================
  # Header and Footer
  # ============================================================================

  defp header do
    """
#{line("=")}
#{center_text("REPORTE DE PROCESAMIENTO DE ARCHIVOS")}
#{line("=")}
"""
  end

  defp footer do
    """
#{line("=")}
#{center_text("FIN DEL REPORTE")}
#{line("=")}
"""
  end

  # ============================================================================
  # Metadata Section
  # ============================================================================

  defp metadata_section(report) do
    """
Fecha de generación: #{format_datetime(report.start_time)}
Directorio procesado: #{report.directory || "N/A"}
Modo de procesamiento: #{format_mode(report.mode)}
"""
  end

  # ============================================================================
  # Executive Summary
  # ============================================================================

  defp summary_section(report) do
    duration_sec = report.total_duration_ms / 1000
    success_rate = ExecutionReport.success_rate(report)

    """
#{line("-")}
RESUMEN EJECUTIVO
#{line("-")}
Total de archivos procesados: #{report.total_files}
  - Archivos CSV: #{report.csv_count}
  - Archivos JSON: #{report.json_count}
  - Archivos LOG: #{report.log_count}
  - Archivos XML: #{report.xml_count}

Tiempo total de procesamiento: #{Float.round(duration_sec, 2)} segundos
Archivos con errores: #{report.error_count}
Tasa de éxito: #{success_rate}%
"""
  end

  # ============================================================================
  # CSV Metrics Section
  # ============================================================================

  defp csv_metrics_section(report) do
    csv_results = filter_by_type(report.results, :csv)

    if length(csv_results) > 0 do
      individual = Enum.map(csv_results, &format_csv_file/1) |> Enum.join("\n")
      consolidated = format_csv_consolidated(csv_results)

      """
#{line("-")}
MÉTRICAS DE ARCHIVOS CSV
#{line("-")}
#{individual}

#{consolidated}
"""
    else
      ""
    end
  end

  defp format_csv_file(%FileResult{status: :ok} = result) do
    m = result.metrics

    best_product = case m[:best_selling_product] do
      %{name: name, quantity: qty} -> "#{name} (#{qty} unidades)"
      product when is_binary(product) -> product
      _ -> "N/A"
    end

    top_category = case m[:top_category] do
      %{name: cat, revenue: rev} -> "#{cat} ($#{format_currency(rev)})"
      %{category: cat, revenue: rev} -> "#{cat} ($#{format_currency(rev)})"
      category when is_binary(category) -> category
      _ -> "N/A"
    end

    """
[Archivo: #{result.filename}]
  * Total de ventas: $#{format_currency(m[:total_sales] || 0)}
  * Productos únicos: #{m[:unique_products] || 0}
  * Producto más vendido: #{best_product}
  * Categoría con mayor ingreso: #{top_category}
  * Promedio de descuento aplicado: #{format_percent(m[:average_discount] || 0)}
  * Rango de fechas procesadas: #{format_date_range(m[:date_range])}
"""
  end

  defp format_csv_file(result) do
    """
[Archivo: #{result.filename}] - ERROR
  * Estado: #{result.status}
  * Error: #{format_errors_brief(result.errors)}
"""
  end

  defp format_csv_consolidated(results) do
    successful = Enum.filter(results, &(&1.status == :ok))

    total_sales = successful
      |> Enum.map(&(get_in(&1.metrics, [:total_sales]) || 0))
      |> Enum.sum()

    all_products = successful
      |> Enum.flat_map(fn r ->
        Map.get(r.metrics, :products, [])
      end)
      |> Enum.uniq()

    """
Totales Consolidados CSV:
  - Ventas totales: $#{format_currency(total_sales)}
  - Productos únicos totales: #{length(all_products)}
"""
  end

  # ============================================================================
  # JSON Metrics Section
  # ============================================================================

  defp json_metrics_section(report) do
    json_results = filter_by_type(report.results, :json)

    if length(json_results) > 0 do
      individual = Enum.map(json_results, &format_json_file/1) |> Enum.join("\n")
      consolidated = format_json_consolidated(json_results)

      """
#{line("-")}
MÉTRICAS DE ARCHIVOS JSON
#{line("-")}
#{individual}

#{consolidated}
"""
    else
      ""
    end
  end

  defp format_json_file(%FileResult{status: :ok} = result) do
    m = result.metrics

    top_actions = case m[:top_actions] do
      actions when is_list(actions) ->
        actions
        |> Enum.take(5)
        |> Enum.with_index(1)
        |> Enum.map(fn {item, idx} ->
          case item do
            %{action: action, count: count} -> "    #{idx}. #{action} (#{count} veces)"
            {action, count} -> "    #{idx}. #{action} (#{count} veces)"
            _ -> "    #{idx}. #{inspect(item)}"
          end
        end)
        |> Enum.join("\n")
      _ -> "    N/A"
    end

    peak_hour = case m[:peak_hour] do
      %{hour: hour, session_count: count} -> "#{hour}:00 (#{count} sesiones)"
      hour when is_integer(hour) -> "#{hour}:00"
      nil -> "N/A"
      _ -> "N/A"
    end

    """
[Archivo: #{result.filename}]
  * Total de usuarios registrados: #{m[:total_users] || 0}
  * Usuarios activos vs inactivos: #{m[:active_users] || 0} activos / #{m[:inactive_users] || 0} inactivos (#{format_percent(m[:active_percentage] || 0)})
  * Promedio de duración de sesión: #{format_duration(m[:avg_session_duration])} minutos
  * Total de páginas visitadas: #{format_number(m[:total_pages_visited] || 0)}
  * Top 5 acciones más comunes:
#{top_actions}
  * Hora pico de actividad: #{peak_hour}
"""
  end

  defp format_json_file(result) do
    """
[Archivo: #{result.filename}] - ERROR
  * Estado: #{result.status}
  * Error: #{format_errors_brief(result.errors)}
"""
  end

  defp format_json_consolidated(results) do
    successful = Enum.filter(results, &(&1.status == :ok))

    total_users = successful
      |> Enum.map(&(get_in(&1.metrics, [:total_users]) || 0))
      |> Enum.sum()

    total_sessions = successful
      |> Enum.map(&(get_in(&1.metrics, [:total_sessions]) || 0))
      |> Enum.sum()

    """
Totales Consolidados JSON:
  - Usuarios totales: #{total_users}
  - Sesiones totales: #{total_sessions}
"""
  end

  # ============================================================================
  # LOG Metrics Section
  # ============================================================================

  defp log_metrics_section(report) do
    log_results = filter_by_type(report.results, :log)

    if length(log_results) > 0 do
      individual = Enum.map(log_results, &format_log_file/1) |> Enum.join("\n")
      consolidated = format_log_consolidated(log_results)

      """
#{line("-")}
MÉTRICAS DE ARCHIVOS LOG
#{line("-")}
#{individual}

#{consolidated}
"""
    else
      ""
    end
  end

  defp format_log_file(%FileResult{status: :ok} = result) do
    m = result.metrics

    distribution = format_level_distribution(m[:level_distribution] || %{})
    top_components = format_top_error_components(m[:top_error_components] || [])
    frequent_errors = format_frequent_errors_list(m[:most_frequent_errors] || [])

    """
[Archivo: #{result.filename}]
  * Total de entradas: #{format_number(m[:total_entries] || 0)}
  * Distribución de logs por nivel:
#{distribution}
  * Errores más frecuentes (análisis de mensajes):
#{frequent_errors}
  * Componentes con más errores:
#{top_components}
  * Errores críticos (ERROR + FATAL): #{m[:critical_errors_count] || 0}
"""
  end

  defp format_log_file(result) do
    """
[Archivo: #{result.filename}] - ERROR
  * Estado: #{result.status}
  * Error: #{format_errors_brief(result.errors)}
"""
  end

  defp format_level_distribution(dist) when map_size(dist) == 0, do: "    N/A"
  defp format_level_distribution(dist) do
    ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]
    |> Enum.map(fn level ->
      case Map.get(dist, level, %{count: 0, percentage: 0.0}) do
        %{count: count, percentage: percent} ->
          "    - #{level}: #{count} (#{format_percent(percent)})"
        {count, percent} ->
          "    - #{level}: #{count} (#{format_percent(percent)})"
        _ ->
          "    - #{level}: 0 (0.0%)"
      end
    end)
    |> Enum.join("\n")
  end

  defp format_frequent_errors_list([]), do: "    N/A"
  defp format_frequent_errors_list(errors) when is_list(errors) do
    errors
    |> Enum.take(3)
    |> Enum.with_index(1)
    |> Enum.map(fn {item, idx} ->
      case item do
        %{message: message, count: count} ->
          "    #{idx}. \"#{String.slice(message, 0..60)}...\" (#{count} veces)"
        %{pattern: pattern, count: count} ->
          "    #{idx}. \"#{pattern}\" (#{count} veces)"
        {pattern, count} ->
          "    #{idx}. \"#{pattern}\" (#{count} veces)"
        _ ->
          "    #{idx}. N/A"
      end
    end)
    |> Enum.join("\n")
  end

  defp format_top_error_components([]), do: "    N/A"
  defp format_top_error_components(components) when is_list(components) do
    components
    |> Enum.take(5)
    |> Enum.with_index(1)
    |> Enum.map(fn {item, idx} ->
      case item do
        %{component: comp, error_count: count} ->
          "    #{idx}. #{comp} (#{count} errores)"
        {comp, count} ->
          "    #{idx}. #{comp} (#{count} errores)"
        _ ->
          "    #{idx}. N/A"
      end
    end)
    |> Enum.join("\n")
  end



  defp format_log_consolidated(results) do
    successful = Enum.filter(results, &(&1.status == :ok))

    total_entries = successful
      |> Enum.map(&(get_in(&1.metrics, [:total_entries]) || 0))
      |> Enum.sum()

    """
Totales Consolidados LOG:
  - Entradas totales: #{format_number(total_entries)}
"""
  end

  # ============================================================================
  # XML Metrics Section (Optional/Extra)
  # ============================================================================

  defp xml_metrics_section(report) do
    xml_results = filter_by_type(report.results, :xml)

    if length(xml_results) > 0 do
      individual = Enum.map(xml_results, &format_xml_file/1) |> Enum.join("\n")

      """
#{line("-")}
MÉTRICAS DE ARCHIVOS XML
#{line("-")}
#{individual}
"""
    else
      ""
    end
  end

  defp format_xml_file(%FileResult{status: :ok} = result) do
    m = result.metrics

    """
[Archivo: #{result.filename}]
  * Total de productos: #{m[:total_products] || 0}
  * Valor total de inventario: $#{format_currency(m[:total_inventory_value] || 0)}
  * Categorías: #{m[:categories_count] || 0}
  * Items con stock bajo: #{length(m[:low_stock_items] || [])}
  * Precio promedio: $#{format_currency(m[:average_price] || 0)}
"""
  end

  defp format_xml_file(result) do
    """
[Archivo: #{result.filename}] - ERROR
  * Estado: #{result.status}
  * Error: #{format_errors_brief(result.errors)}
"""
  end

  # ============================================================================
  # Performance Section
  # ============================================================================

  defp performance_section(report) do
    avg_time = if report.total_files > 0 do
      report.total_duration_ms / report.total_files
    else
      0
    end

    # Check if we have benchmark data in the report
    benchmark_info = if Map.has_key?(report, :benchmark_data) && report.benchmark_data != nil do
      format_benchmark_comparison(report.benchmark_data)
    else
      ""
    end

    """
#{line("-")}
ANÁLISIS DE RENDIMIENTO
#{line("-")}
#{benchmark_info}Tiempo total: #{report.total_duration_ms}ms (#{Float.round(report.total_duration_ms / 1000, 2)}s)
Promedio por archivo: #{Float.round(avg_time, 2)}ms
Modo utilizado: #{format_mode(report.mode)}
Archivos procesados: #{report.total_files}
"""
  end

  defp format_benchmark_comparison(benchmark) do
    max_mem_kb = max(benchmark.sequential.memory_kb || 0, benchmark.parallel.memory_kb || 0)

    """
Comparación Secuencial vs Paralelo:
  * Tiempo secuencial: #{Float.round(benchmark.sequential.duration_sec, 2)} segundos
  * Tiempo paralelo: #{Float.round(benchmark.parallel.duration_sec, 2)} segundos
  * Factor de mejora: #{benchmark.comparison.speedup_factor}x veces más rápido
  * Procesos utilizados: #{Map.get(benchmark, :processes_used, "N/A")}
  * Memoria máxima: #{Float.round(max_mem_kb / 1024, 2)} MB

"""
  end

  # ============================================================================
  # Errors Section
  # ============================================================================

  defp errors_section(report) do
    error_results = Enum.filter(report.results, fn r ->
      r.status == :error or r.status == :partial
    end)

    if length(error_results) > 0 do
      errors_text = Enum.map(error_results, &format_error_entry/1) |> Enum.join("\n")

      """
#{line("-")}
ERRORES Y ADVERTENCIAS
#{line("-")}
#{errors_text}
"""
    else
      """
#{line("-")}
ERRORES Y ADVERTENCIAS
#{line("-")}
No hay errores ni advertencias que reportar.
"""
    end
  end

  defp format_error_entry(%FileResult{status: :error} = result) do
    error_msg = format_errors_brief(result.errors)
    "[X] #{result.filename}: #{error_msg}"
  end

  defp format_error_entry(%FileResult{status: :partial} = result) do
    "[!] #{result.filename}: Procesado parcialmente (#{result.lines_failed} líneas con error)"
  end

  # ============================================================================
  # Formatting Utilities
  # ============================================================================

  defp filter_by_type(results, type) do
    Enum.filter(results, fn r -> r.type == type end)
  end

  defp line(char), do: String.duplicate(char, @report_width)

  defp center_text(text) do
    padding = div(@report_width - String.length(text), 2)
    String.duplicate(" ", max(padding, 0)) <> text
  end

  defp format_mode(:sequential), do: "Secuencial"
  defp format_mode(:parallel), do: "Paralelo"
  defp format_mode("sequential"), do: "Secuencial"
  defp format_mode("parallel"), do: "Paralelo"
  defp format_mode(mode), do: to_string(mode)

  defp format_currency(value) when is_float(value) or is_integer(value) do
    value
    |> Kernel./(1)
    |> Float.round(2)
    |> :erlang.float_to_binary(decimals: 2)
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
  end
  defp format_currency(_), do: "0.00"

  defp format_percent(value) when is_float(value) or is_integer(value) do
    "#{Float.round(value, 1)}%"
  end
  defp format_percent(_), do: "0.0%"

  defp format_number(value) when is_integer(value) do
    value
    |> to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
  end
  defp format_number(value), do: to_string(value)

  defp format_duration(seconds) when is_number(seconds) do
    minutes = seconds / 60
    Float.round(minutes, 1)
  end
  defp format_duration(_), do: "0.0"

  defp format_date_range(%{from: from_date, to: to_date}) when is_binary(from_date) and is_binary(to_date) do
    "#{from_date} a #{to_date}"
  end
  defp format_date_range({start_date, end_date}) when is_binary(start_date) and is_binary(end_date) do
    "#{start_date} a #{end_date}"
  end
  defp format_date_range(_), do: "N/A"

  defp format_errors_brief([]), do: "Unknown error"
  defp format_errors_brief([first | _rest]) do
    error_text = case first do
      {_line, msg} -> msg
      msg when is_binary(msg) -> msg
      _ -> "Error en procesamiento"
    end

    # Wrap long error messages to multiple lines with indentation
    wrap_text(error_text, 80, "     ")
  end
  defp format_errors_brief(_), do: "Error en procesamiento"

  defp wrap_text(text, max_width, indent) when is_binary(text) do
    text
    |> String.split("; ")
    |> Enum.map(fn segment ->
      if String.length(segment) > max_width do
        segment
        |> String.graphemes()
        |> Enum.chunk_every(max_width)
        |> Enum.map(&Enum.join/1)
        |> Enum.join("\n#{indent}")
      else
        segment
      end
    end)
    |> Enum.join(";\n#{indent}")
  end
  defp wrap_text(text, _max_width, _indent), do: inspect(text)

  #defp format_timestamp(datetime) do
  #  datetime
  #  |> DateTime.to_string()
  #  |> String.replace(~r/[:\s\.]/, "_")
  #  |> String.slice(0..18)
  #end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
end
