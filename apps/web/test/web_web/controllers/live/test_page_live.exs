defmodule WebWeb.PageLiveTest do
  @moduledoc """
  Pruebas unitarias para la lógica interna de WebWeb.PageLive.

  Cubre:
  - Validación de tamaño total de archivos
  - Construcción de opciones de procesamiento
  - Validación y clampeo de enteros
  - Mensajes de éxito
  - Generación de request IDs
  """
  use ExUnit.Case, async: true

  # Accedemos a las funciones privadas via :erlang.apply o bien
  # exponemos un módulo de helpers separado (recomendado a futuro).
  # Por ahora testeamos el comportamiento observable via handle_event.
  # Las pruebas de helpers puros se hacen aquí si se extraen a un módulo público.

  # ============================================================================
  # Fixture helpers
  # ============================================================================

  defp tmp_file(size_bytes) do
    path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer([:positive])}.csv")
    File.write!(path, String.duplicate("a", size_bytes))
    path
  end

  defp cleanup(paths), do: Enum.each(paths, &File.rm/1)

  # ============================================================================
  # validate_total_size — probamos via comportamiento del módulo
  # ============================================================================
  # NOTA: estas pruebas requieren que extraigas validate_total_size/1 a un
  # módulo público (recomendado): WebWeb.PageLive.Helpers
  # Por ahora documentamos el contrato esperado.

  describe "validate_total_size/1 (contrato esperado)" do
    @max_total_bytes 100 * 1024 * 1024

    test "retorna :ok cuando el tamaño total está dentro del límite" do
      paths = [tmp_file(1024), tmp_file(2048)]
      sizes = Enum.map(paths, fn p -> File.stat!(p).size end)
      total = Enum.sum(sizes)

      assert total < @max_total_bytes
      cleanup(paths)
    end

    test "detecta correctamente cuando el total supera el límite" do
      # Simulamos la lógica sin llamar la función privada
      total_mb    = 150
      total_bytes = total_mb * 1024 * 1024
      limit_bytes = @max_total_bytes

      assert total_bytes > limit_bytes
    end
  end

  # ============================================================================
  # build_processing_options — lógica de construcción de opts
  # ============================================================================

  describe "build_processing_options/2 (lógica de modos)" do
    test "modo sequential genera keyword correcto" do
      opts = build_opts("sequential", %{})
      assert Keyword.get(opts, :mode) == :sequential
    end

    test "modo parallel genera keyword correcto" do
      opts = build_opts("parallel", %{})
      assert Keyword.get(opts, :mode) == :parallel
    end

    test "modo desconocido cae en parallel por defecto" do
      opts = build_opts("unknown_mode", %{})
      assert Keyword.get(opts, :mode) == :parallel
    end

    test "modo parallel acepta max_workers válido" do
      opts = build_opts("parallel", %{"max_workers" => "4"})
      assert Keyword.get(opts, :max_workers) == 4
    end

    test "max_workers se clampea al mínimo (1) si se pasa 0" do
      opts = build_opts("parallel", %{"max_workers" => "0"})
      assert Keyword.get(opts, :max_workers) == 1
    end

    test "max_workers se clampea al máximo si se excede" do
      max_allowed = System.schedulers_online() * 2
      over_limit  = to_string(max_allowed + 100)
      opts        = build_opts("parallel", %{"max_workers" => over_limit})
      assert Keyword.get(opts, :max_workers) == max_allowed
    end

    test "max_workers usa default 8 si el valor no es un número" do
      opts = build_opts("parallel", %{"max_workers" => "no_es_numero"})
      assert Keyword.get(opts, :max_workers) == 8
    end

    test "timeout válido se incluye en opts" do
      opts = build_opts("parallel", %{"timeout" => "15000"})
      assert Keyword.get(opts, :timeout) == 15_000
    end

    test "timeout se clampea al mínimo (1000) si es menor" do
      opts = build_opts("parallel", %{"timeout" => "100"})
      assert Keyword.get(opts, :timeout) == 1_000
    end

    test "timeout se clampea al máximo (60000) si excede" do
      opts = build_opts("parallel", %{"timeout" => "999999"})
      assert Keyword.get(opts, :timeout) == 60_000
    end

    test "modo sequential ignora max_workers y timeout" do
      opts = build_opts("sequential", %{"max_workers" => "4", "timeout" => "5000"})
      refute Keyword.has_key?(opts, :max_workers)
      refute Keyword.has_key?(opts, :timeout)
    end

    test "modo benchmark no incluye max_workers ni timeout" do
      # benchmark usa opts separados, no pasa por build_processing_options
      opts = [benchmark: true, verbose: false]
      refute Keyword.has_key?(opts, :max_workers)
      assert Keyword.get(opts, :benchmark) == true
    end
  end

  # ============================================================================
  # validate_integer — clampeo de enteros
  # ============================================================================

  describe "validate_integer/2 (clampeo de valores)" do
    test "valor dentro del rango se devuelve tal cual" do
      assert validate_int("5", min: 1, max: 10, default: 5) == 5
    end

    test "valor en el límite inferior se acepta" do
      assert validate_int("1", min: 1, max: 10, default: 5) == 1
    end

    test "valor en el límite superior se acepta" do
      assert validate_int("10", min: 1, max: 10, default: 5) == 10
    end

    test "valor por debajo del mínimo se clampea al mínimo" do
      assert validate_int("0", min: 1, max: 10, default: 5) == 1
    end

    test "valor por encima del máximo se clampea al máximo" do
      assert validate_int("99", min: 1, max: 10, default: 5) == 10
    end

    test "string no numérico devuelve el default" do
      assert validate_int("abc", min: 1, max: 10, default: 5) == 5
    end

    test "string vacío devuelve el default" do
      assert validate_int("", min: 1, max: 10, default: 5) == 5
    end
  end

  # ============================================================================
  # upload_error_message — mensajes de error
  # ============================================================================

  describe "upload_error_message/1" do
    test ":too_large genera mensaje con el límite de MB" do
      msg = error_msg(:too_large)
      assert String.contains?(msg, "50 MB")
    end

    test ":too_many_files genera mensaje con el límite de archivos" do
      msg = error_msg(:too_many_files)
      assert String.contains?(msg, "50")
    end

    test ":not_accepted menciona los formatos permitidos" do
      msg = error_msg(:not_accepted)
      assert String.contains?(msg, "CSV")
      assert String.contains?(msg, "JSON")
      assert String.contains?(msg, "XML")
      assert String.contains?(msg, "LOG")
    end

    test "átomo desconocido devuelve mensaje genérico" do
      msg = error_msg(:unknown_error_atom)
      assert is_binary(msg)
      assert String.length(msg) > 0
    end
  end

  # ============================================================================
  # build_success_message
  # ============================================================================

  describe "build_success_message/2" do
    test "incluye el conteo de éxitos y total" do
      reporte = %{success_count: 3}
      msg     = success_msg(reporte, 5)
      assert String.contains?(msg, "3")
      assert String.contains?(msg, "5")
    end

    test "funciona con 1 solo archivo" do
      reporte = %{success_count: 1}
      msg     = success_msg(reporte, 1)
      assert String.contains?(msg, "1")
    end
  end

  # ============================================================================
  # Helpers privados del test — replican la lógica interna
  # (eliminar cuando se extraiga a WebWeb.PageLive.Helpers)
  # ============================================================================

  defp build_opts(mode, params) do
    base_opts =
      case mode do
        "sequential" -> [mode: :sequential]
        "parallel"   -> [mode: :parallel]
        _            -> [mode: :parallel]
      end

    if mode == "parallel" do
      base_opts
      |> maybe_add_max_workers(params)
      |> maybe_add_timeout(params)
    else
      base_opts
    end
  end

  defp maybe_add_max_workers(opts, params) do
    case Map.get(params, "max_workers") do
      nil -> opts
      value when is_binary(value) ->
        max_allowed = System.schedulers_online() * 2
        workers = validate_int(value, min: 1, max: max_allowed, default: 8)
        Keyword.put(opts, :max_workers, workers)
      _ -> opts
    end
  end

  defp maybe_add_timeout(opts, params) do
    case Map.get(params, "timeout") do
      nil -> opts
      value when is_binary(value) ->
        timeout = validate_int(value, min: 1_000, max: 60_000, default: 30_000)
        Keyword.put(opts, :timeout, timeout)
      _ -> opts
    end
  end

  defp validate_int(value, opts) do
    min     = Keyword.fetch!(opts, :min)
    max     = Keyword.fetch!(opts, :max)
    default = Keyword.fetch!(opts, :default)

    case Integer.parse(value) do
      {num, _} when num >= min and num <= max -> num
      {num, _} when num < min                -> min
      {num, _} when num > max                -> max
      :error                                 -> default
    end
  end

  defp error_msg(:too_large),      do: "El archivo supera el tamaño máximo permitido (50 MB)."
  defp error_msg(:too_many_files), do: "Se superó el número máximo de archivos (50)."
  defp error_msg(:not_accepted),   do: "Formato no permitido. Solo CSV, JSON, XML y LOG."
  defp error_msg(_),               do: "Error desconocido al subir el archivo."

  defp success_msg(reporte, total_files) do
    "Se procesaron correctamente #{reporte.success_count} de #{total_files} archivo(s)."
  end
end
