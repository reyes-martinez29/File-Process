defmodule WebWeb.HomeLiveTest do
  @moduledoc """
  Pruebas LiveView para la página de inicio (home).
  """
  use WebWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  # ============================================================================
  # Mount y estado inicial
  # ============================================================================

  describe "mount/3 — estado inicial" do
    test "monta correctamente y muestra la página home", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live")

      assert html =~ "Procesador de Archivos"
      assert html =~ "Configuración de Procesamiento"
      assert html =~ "Vista Previa"
    end

    test "el modo secuencial viene seleccionado por defecto", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live")

      assert html =~ "Modo Secuencial"
    end

    test "el panel de configuración avanzada está oculto al inicio", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live")

      refute html =~ "Max Workers"
    end

    test "el aside muestra mensaje de ningún archivo al inicio", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live")

      assert html =~ "Ningún archivo seleccionado aún"
    end

    test "el peso total muestra 0.0 MB al inicio", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live")

      assert html =~ "0.0 MB"
    end

    test "el botón Comenzar Procesamiento está presente", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live")

      assert html =~ "Comenzar Procesamiento"
    end

    test "los tres modos de procesamiento están presentes", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live")

      assert html =~ "Modo Secuencial"
      assert html =~ "Modo Paralelo"
      assert html =~ "Modo Benchmark"
    end
  end

  # ============================================================================
  # Selección de modo de procesamiento
  # ============================================================================

  describe "handle_event set_mode" do
    test "cambiar a modo paralelo muestra toggle de configuración avanzada", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      html = view |> element("input[value='parallel']") |> render_click()

      assert html =~ "Mostrar Configuración Avanzada"
    end

    test "cambiar a modo benchmark no muestra toggle de configuración avanzada", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      html = view |> element("input[value='benchmark']") |> render_click()

      assert html =~ "Modo Benchmark"
      refute html =~ "Mostrar Configuración Avanzada"
    end

    test "cambiar de paralelo a secuencial oculta la config avanzada", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view |> element("input[value='parallel']") |> render_click()
      view |> element("input[type='checkbox']") |> render_click()
      html = view |> element("input[value='sequential']") |> render_click()

      refute html =~ "Max Workers"
    end

    test "volver a secuencial desde paralelo oculta el toggle avanzado", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view |> element("input[value='parallel']") |> render_click()
      html = view |> element("input[value='sequential']") |> render_click()

      refute html =~ "Mostrar Configuración Avanzada"
    end
  end

  # ============================================================================
  # Configuración avanzada (solo modo paralelo)
  # ============================================================================

  describe "handle_event toggle_advanced" do
    test "activar el checkbox en modo paralelo muestra el panel avanzado", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view |> element("input[value='parallel']") |> render_click()
      html = view |> element("input[type='checkbox']") |> render_click()

      assert html =~ "Max Workers"
      assert html =~ "Timeout (ms)"
    end

    test "desactivar el checkbox oculta el panel avanzado", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view |> element("input[value='parallel']") |> render_click()
      view |> element("input[type='checkbox']") |> render_click()
      html = view |> element("input[type='checkbox']") |> render_click()

      refute html =~ "Max Workers"
    end

    test "el panel avanzado muestra el límite correcto de workers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view |> element("input[value='parallel']") |> render_click()
      html = view |> element("input[type='checkbox']") |> render_click()

      assert html =~ to_string(System.schedulers_online() * 2)
    end

    test "el panel avanzado muestra nota de rendimiento", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view |> element("input[value='parallel']") |> render_click()
      html = view |> element("input[type='checkbox']") |> render_click()

      assert html =~ "Nota de Rendimiento"
    end

    test "el panel avanzado tiene inputs de max_workers y timeout", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view |> element("input[value='parallel']") |> render_click()
      html = view |> element("input[type='checkbox']") |> render_click()

      assert html =~ ~s(name="max_workers")
      assert html =~ ~s(name="timeout")
    end
  end

  # ============================================================================
  # Validación: sin archivos
  # El flash en LiveView se inyecta en el layout root via put_flash.
  # Para verificarlo usamos render(view) después del evento, que incluye
  # el HTML completo re-renderizado con el flash si está en el template.
  # ============================================================================

  describe "handle_event process_files — sin archivos" do
    test "procesar sin archivos permanece en home sin crashear", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      # No debe lanzar excepción
      render_submit(view, "process_files", %{})

      # Sigue mostrando la página home
      assert render(view) =~ "Configuración de Procesamiento"
    end

    test "procesar benchmark sin archivos permanece en home sin crashear", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      render_submit(view, "process_benchmark", %{})

      assert render(view) =~ "Configuración de Procesamiento"
    end

    test "procesar sin archivos no navega a benchmark", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      render_submit(view, "process_files", %{})

      refute render(view) =~ "SYSTEM BENCHMARK"
    end
  end

  # ============================================================================
  # Upload: vista previa y cancelación
  # Usamos render(view) para leer el HTML actualizado.
  # Para el ref usamos :sys.get_state para acceder al socket interno.
  # ============================================================================

  describe "handle_event cancel_upload" do
    test "subir un archivo lo muestra en el aside", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view
      |> file_input("#upload-form", :archivos, [build_upload("datos.csv", "text/csv")])
      |> render_upload("datos.csv")

      assert render(view) =~ "datos.csv"
    end

    test "cancelar un archivo lo elimina del aside", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view
      |> file_input("#upload-form", :archivos, [build_upload("datos.csv", "text/csv")])
      |> render_upload("datos.csv")

      assert render(view) =~ "datos.csv"

      # Obtenemos el ref desde el estado interno del proceso LiveView
      ref = get_first_upload_ref(view)
      view |> element("[phx-click='cancel_upload']") |> render_click(%{"ref" => ref})

      refute render(view) =~ "datos.csv"
    end

    test "cancelar el único archivo vuelve a mostrar el mensaje vacío", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view
      |> file_input("#upload-form", :archivos, [build_upload("datos.csv", "text/csv")])
      |> render_upload("datos.csv")

      ref = get_first_upload_ref(view)
      view |> element("[phx-click='cancel_upload']") |> render_click(%{"ref" => ref})

      assert render(view) =~ "Ningún archivo seleccionado aún"
    end

    test "cancelar archivo elimina el icono de advertencia si era inválido", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view
      |> file_input("#upload-form", :archivos, [build_upload("doc.pdf", "application/pdf")])
      |> render_upload("doc.pdf")

      assert render(view) =~ "⚠️"

      ref = get_first_upload_ref(view)
      view |> element("[phx-click='cancel_upload']") |> render_click(%{"ref" => ref})

      refute render(view) =~ "⚠️"
    end
  end

  # ============================================================================
  # Panel de Vista Previa reactivo
  # ============================================================================

  describe "panel de Vista Previa" do
    test "subir un CSV válido muestra el nombre en la lista", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view
      |> file_input("#upload-form", :archivos, [build_upload("reporte.csv", "text/csv")])
      |> render_upload("reporte.csv")

      assert render(view) =~ "reporte.csv"
    end

    test "archivo con extensión inválida muestra error de formato", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view
      |> file_input("#upload-form", :archivos, [build_upload("doc.pdf", "application/pdf")])
      |> render_upload("doc.pdf")

      assert render(view) =~ "Formato no permitido"
    end

    test "archivo inválido muestra icono de advertencia", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view
      |> file_input("#upload-form", :archivos, [build_upload("doc.pdf", "application/pdf")])
      |> render_upload("doc.pdf")

      assert render(view) =~ "⚠️"
    end

    test "archivo válido muestra icono de documento 📄", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view
      |> file_input("#upload-form", :archivos, [build_upload("datos.csv", "text/csv")])
      |> render_upload("datos.csv")

      assert render(view) =~ "📄"
    end

    test "archivo inválido muestra panel Problemas detectados", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live")

      view
      |> file_input("#upload-form", :archivos, [build_upload("doc.pdf", "application/pdf")])
      |> render_upload("doc.pdf")

      assert render(view) =~ "Problemas detectados"
    end

    test "sin archivos no muestra panel Problemas detectados", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live")

      refute html =~ "Problemas detectados"
    end
  end

  # ============================================================================
  # Helpers privados
  # ============================================================================

  defp build_upload(name, type, content \\ "col1,col2\n1,2\n3,4") do
    %{
      last_modified: System.system_time(:millisecond),
      name:          name,
      content:       content,
      type:          type,
      size:          byte_size(content)
    }
  end

  # Obtiene el ref del primer entry de upload desde el estado interno del proceso
  defp get_first_upload_ref(view) do
    %{socket: %{assigns: %{uploads: %{archivos: %{entries: [entry | _]}}}}} =
      :sys.get_state(view.pid)

    entry.ref
  end
end
