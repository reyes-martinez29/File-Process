defmodule FProcess.UI do
  @moduledoc """
  Small console UI helpers for friendly output: headers, progress wrapper and summary.
  """

  alias FProcess.Structs.ExecutionReport
  @reset IO.ANSI.reset()
  @green IO.ANSI.green()
  @red IO.ANSI.red()
  @yellow IO.ANSI.yellow()
  @cyan IO.ANSI.cyan()
  @bold IO.ANSI.bright()

  def header(mode, total) do
    mode_str = String.capitalize(to_string(mode))
    IO.puts("")
    IO.puts("#{@bold}#{mode_str} processing: #{total} files#{@reset}")
  end

  def start_progress(total) do
    FProcess.Utils.Progress.start(total)
  end

  def update_progress(current, total) do
    FProcess.Utils.Progress.update(current, total)
  end

  def stop_progress() do
    FProcess.Utils.Progress.stop()
  end

  def summary(%ExecutionReport{} = report) do
    total = report.total_files
    success = report.success_count || 0
    error = report.error_count || 0
    partial = report.partial_count || 0
    duration_ms = report.total_duration_ms || 0

    # If there are errors print a warning line
    IO.puts("")
    if error > 0 do
      IO.puts("#{@yellow}⚠️  Directory processing complete with #{error} errors#{@reset}")
    else
      IO.puts("#{@green}Directory processing complete#{@reset}")
    end

    IO.puts("Files processed: #{total}")
    IO.puts("#{@green}✓ Successful: #{success}#{@reset}")
    IO.puts("#{@red}✗ Failed: #{error}#{@reset}")
    if partial > 0 do
      IO.puts("#{@cyan}● Partial: #{partial}#{@reset}")
    end

    # If processing a single file, print detailed metrics (only if successful)
    if total == 1 and length(report.results) == 1 do
      result = List.first(report.results)
      if result.status == :ok do
        print_file_metrics(result)
      end
    end

    if error > 0 do
      IO.puts("")
      IO.puts("Errors:")

      error_results = report.results |> Enum.filter(fn r -> r.status == :error end)
      max_show = 5

      error_results
      |> Enum.take(max_show)
      |> Enum.each(fn r ->
        err_msg = extract_first_error(r) |> truncate(120)
        IO.puts("  • #{r.filename}: #{err_msg}")
      end)

      remaining = length(error_results) - min(length(error_results), max_show)
      if remaining > 0 do
        IO.puts("  ... and #{remaining} more errors. See full report for details.")
      end
    end

    IO.puts("")
    IO.puts("Time: #{duration_ms}ms")
  end

  def report_saved(path) when is_binary(path) do
    IO.puts("Report: #{path}")
  end

  # ============================================================================
  # Private Functions - Single File Metrics Display
  # ============================================================================

  defp print_file_metrics(%{type: :csv, metrics: m, filename: filename}) do
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

    IO.puts("")
    IO.puts("#{@bold}#{@cyan}[Archivo: #{filename}]#{@reset}")
    IO.puts("  * Total de ventas: $#{format_currency(m[:total_sales] || 0)}")
    IO.puts("  * Productos únicos: #{m[:unique_products] || 0}")
    IO.puts("  * Producto más vendido: #{best_product}")
    IO.puts("  * Categoría con mayor ingreso: #{top_category}")
    IO.puts("  * Promedio de descuento aplicado: #{format_percent(m[:average_discount] || 0)}")
    IO.puts("  * Rango de fechas procesadas: #{format_date_range(m[:date_range])}")
  end

  defp print_file_metrics(%{type: :json, metrics: m, filename: filename}) do
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

    IO.puts("")
    IO.puts("#{@bold}#{@cyan}[Archivo: #{filename}]#{@reset}")
    IO.puts("  * Total de usuarios registrados: #{m[:total_users] || 0}")
    IO.puts("  * Usuarios activos vs inactivos: #{m[:active_users] || 0} activos / #{m[:inactive_users] || 0} inactivos (#{format_percent(m[:active_percentage] || 0)})")
    IO.puts("  * Promedio de duración de sesión: #{format_duration(m[:avg_session_duration])} minutos")
    IO.puts("  * Total de páginas visitadas: #{format_number(m[:total_pages_visited] || 0)}")
    IO.puts("  * Top 5 acciones más comunes:")
    IO.puts(top_actions)
    IO.puts("  * Hora pico de actividad: #{peak_hour}")
  end

  defp print_file_metrics(%{type: :xml, metrics: m, filename: filename}) do
    IO.puts("")
    IO.puts("#{@bold}#{@cyan}[Archivo: #{filename}]#{@reset}")
    IO.puts("  * Total de productos: #{m[:total_products] || 0}")
    IO.puts("  * Valor total de inventario: $#{format_currency(m[:total_inventory_value] || 0)}")
    IO.puts("  * Categorías: #{m[:categories_count] || 0}")
    IO.puts("  * Items con stock bajo: #{length(m[:low_stock_items] || [])}")
    IO.puts("  * Precio promedio: $#{format_currency(m[:average_price] || 0)}")
  end

  defp print_file_metrics(%{type: :log, metrics: m, filename: filename}) do
    distribution = format_level_distribution(m[:level_distribution] || %{})
    top_components = format_top_error_components(m[:top_error_components] || [])
    frequent_errors = format_frequent_errors_list(m[:most_frequent_errors] || [])

    IO.puts("")
    IO.puts("#{@bold}#{@cyan}[Archivo: #{filename}]#{@reset}")
    IO.puts("  * Total de entradas: #{format_number(m[:total_entries] || 0)}")
    IO.puts("  * Distribución de logs por nivel:")
    IO.puts(distribution)
    IO.puts("  * Errores más frecuentes (análisis de mensajes):")
    IO.puts(frequent_errors)
    IO.puts("  * Componentes con más errores:")
    IO.puts(top_components)
    IO.puts("  * Errores críticos (ERROR + FATAL): #{m[:critical_errors_count] || 0}")
  end

  defp print_file_metrics(_), do: :ok

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

  # ============================================================================
  # Private Functions - Helpers
  # ============================================================================

  defp format_currency(value) when is_number(value) do
    :erlang.float_to_binary(value / 1, decimals: 2)
  end
  defp format_currency(_), do: "0.00"

  defp format_percent(value) when is_number(value) do
    "#{:erlang.float_to_binary(value, decimals: 1)}%"
  end
  defp format_percent(_), do: "0.0%"

  defp format_number(value) when is_integer(value) and value >= 1_000_000 do
    millions = value / 1_000_000
    "#{:erlang.float_to_binary(millions, decimals: 1)}M"
  end
  defp format_number(value) when is_integer(value) and value >= 1_000 do
    thousands = value / 1_000
    "#{:erlang.float_to_binary(thousands, decimals: 1)}K"
  end
  defp format_number(value) when is_integer(value), do: Integer.to_string(value)
  defp format_number(_), do: "0"

  defp format_duration(nil), do: "N/A"
  defp format_duration(value) when is_number(value) do
    :erlang.float_to_binary(value / 1, decimals: 2)
  end
  defp format_duration(_), do: "N/A"

  defp format_date_range(nil), do: "N/A"
  defp format_date_range(%{from: from_date, to: to_date}) when is_binary(from_date) and is_binary(to_date) do
    "#{from_date} a #{to_date}"
  end
  defp format_date_range(%{"from" => from_date, "to" => to_date}) when is_binary(from_date) and is_binary(to_date) do
    "#{from_date} a #{to_date}"
  end
  defp format_date_range(_), do: "N/A"

  defp extract_first_error(%{errors: errors}) when is_list(errors) do
    case errors do
      [first | _] when is_binary(first) -> first
      [{_line, msg} | _] -> msg
      _ -> "Unknown error"
    end
  end

  defp extract_first_error(_), do: "Unknown error"

  defp truncate(str, max) when is_binary(str) and byte_size(str) > max do
    <<prefix::binary-size(max - 3), _rest::binary>> = str
    prefix <> "..."
  end

  defp truncate(str, _), do: str
end
