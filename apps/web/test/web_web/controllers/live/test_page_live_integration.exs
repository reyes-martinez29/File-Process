defmodule WebWeb.PageLiveIntegrationTest do
  @moduledoc """
  Pruebas de integración end-to-end para el flujo completo de PageLive.

  """
  use WebWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  # ============================================================================
  # Setup
  # ============================================================================

  setup do
    tmp = System.tmp_dir!()

    csv_path  = Path.join(tmp, "test_#{unique()}.csv")
    json_path = Path.join(tmp, "test_#{unique()}.json")
    xml_path  = Path.join(tmp, "test_#{unique()}.xml")
    log_path  = Path.join(tmp, "test_#{unique()}.log")
    bad_path  = Path.join(tmp, "test_#{unique()}.pdf")

    File.write!(csv_path,  "col1,col2,col3\n1,2,3\n4,5,6\n7,8,9\n")
    File.write!(json_path, ~s([{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]))
    File.write!(xml_path,  "<root><item id=\"1\">Hola</item><item id=\"2\">Mundo</item></root>")
    File.write!(log_path,  "2024-01-01 INFO Servicio iniciado\n2024-01-01 ERROR Fallo\n")
    File.write!(bad_path,  "%PDF-1.4 contenido falso de pdf")

    on_exit(fn ->
      Enum.each([csv_path, json_path, xml_path, log_path, bad_path], &File.rm/1)
    end)

    %{
      csv:  %{path: csv_path,  name: Path.basename(csv_path),  type: "text/csv"},
      json: %{path: json_path, name: Path.basename(json_path), type: "application/json"},
      xml:  %{path: xml_path,  name: Path.basename(xml_path),  type: "application/xml"},
      log:  %{path: log_path,  name: Path.basename(log_path),  type: "text/plain"},
      bad:  %{path: bad_path,  name: Path.basename(bad_path),  type: "application/pdf"}
    }
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp unique, do: System.unique_integer([:positive])

  defp to_upload(%{path: path, name: name, type: type}) do
    content = File.read!(path)
    %{
      last_modified: System.system_time(:millisecond),
      name:          name,
      content:       content,
      type:          type,
      size:          byte_size(content)
    }
  end

  # Sube una lista de archivos uno por uno. render_upload espera
  # un solo nombre de archivo por llamada, no una lista.
  defp upload_files(view, files) do
    uploads = Enum.map(files, &to_upload/1)
    input   = file_input(view, "#upload-form", :archivos, uploads)
    Enum.each(files, fn f -> render_upload(input, f.name) end)
    view
  end

  defp flash(view) do
    :sys.get_state(view.pid).socket.assigns.flash
  end

  # ============================================================================
  # Estado inicial
  # ============================================================================

  describe "estado inicial" do
    test "monta la página home correctamente", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live")
      assert html =~ "Configuración de Procesamiento"
      assert html =~ "Ningún archivo seleccionado aún"
    end

    test "el modo secuencial viene activo por defecto", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live")
      assert html =~ "Modo Secuencial"
      refute html =~ "Max Workers"
    end

    test "no hay errores visibles al inicio", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live")
      refute html =~ "Problemas detectados"
    end
  end

  # ============================================================================
  # Upload
  # ============================================================================

  describe "upload de archivos reales" do
    test "subir un CSV válido lo muestra en el aside", %{conn: conn, csv: csv} do
      {:ok, view, _} = live(conn, ~p"/live")
      upload_files(view, [csv])
      assert render(view) =~ csv.name
    end

    test "subir múltiples tipos válidos los muestra todos", %{conn: conn, csv: csv, json: json, xml: xml} do
      {:ok, view, _} = live(conn, ~p"/live")
      upload_files(view, [csv, json, xml])
      html = render(view)
      assert html =~ csv.name
      assert html =~ json.name
      assert html =~ xml.name
    end

    test "el contador de archivos se actualiza al subir", %{conn: conn, csv: csv} do
      {:ok, view, _} = live(conn, ~p"/live")
      upload_files(view, [csv])
      refute render(view) =~ "Ningún archivo seleccionado aún"
    end

    test "archivo con extensión no permitida muestra error en aside", %{conn: conn, bad: bad} do
      {:ok, view, _} = live(conn, ~p"/live")
      upload_files(view, [bad])
      html = render(view)
      assert html =~ "Formato no permitido"
      assert html =~ "Problemas detectados"
    end

    test "cancelar un archivo lo elimina de la lista", %{conn: conn, csv: csv} do
      {:ok, view, _} = live(conn, ~p"/live")
      upload_files(view, [csv])
      assert render(view) =~ csv.name
      view |> element("[phx-click='cancel_upload']") |> render_click()
      refute render(view) =~ csv.name
    end
  end

  # ============================================================================
  # Validación sin archivos
  # ============================================================================

  describe "validación: sin archivos seleccionados" do
    test "procesar sin archivos pone flash de error", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/live")
      render_submit(view, "process_files", %{})
      assert flash(view)["error"] =~ "seleccionar"
    end

    test "benchmark sin archivos pone flash de error", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/live")
      render_submit(view, "process_benchmark", %{})
      assert flash(view)["error"] =~ "seleccionar"
    end
  end

  # ============================================================================
  # Procesamiento con FProcess real
  # ============================================================================

  describe "flujo de procesamiento con FProcess real" do
    test "procesar un CSV válido pone flash de éxito", %{conn: conn, csv: csv} do
      {:ok, view, _} = live(conn, ~p"/live")
      upload_files(view, [csv])
      render_submit(view, "process_files", %{"processing_mode" => "sequential"})
      assert flash(view)["info"] =~ "procesaron"
    end

    test "procesar en modo paralelo también pone flash de éxito", %{conn: conn, csv: csv} do
      {:ok, view, _} = live(conn, ~p"/live")
      view |> element("input[value='parallel']") |> render_click()
      upload_files(view, [csv])
      render_submit(view, "process_files", %{"processing_mode" => "parallel"})
      assert flash(view)["info"] =~ "procesaron"
    end

    test "después de procesar, la lista de archivos queda vacía", %{conn: conn, csv: csv} do
      {:ok, view, _} = live(conn, ~p"/live")
      upload_files(view, [csv])
      render_submit(view, "process_files", %{})
      assert render(view) =~ "Ningún archivo seleccionado aún"
    end
  end

  # ============================================================================
  # Benchmark con FProcess real
  # ============================================================================

  describe "flujo de benchmark con FProcess real" do
    test "ejecutar benchmark muestra la página de resultados", %{conn: conn, csv: csv} do
      {:ok, view, _} = live(conn, ~p"/live")
      view |> element("input[value='benchmark']") |> render_click()
      upload_files(view, [csv])
      render_submit(view, "process_benchmark", %{})
      html = render(view)
      assert html =~ "SYSTEM BENCHMARK"
      assert html =~ "Sequential"
    end

    test "desde benchmark, go_home vuelve al home", %{conn: conn, csv: csv} do
      {:ok, view, _} = live(conn, ~p"/live")
      view |> element("input[value='benchmark']") |> render_click()
      upload_files(view, [csv])
      render_submit(view, "process_benchmark", %{})
      assert render(view) =~ "SYSTEM BENCHMARK"
      view |> element("[phx-click='go_home']") |> render_click()
      assert render(view) =~ "Configuración de Procesamiento"
    end
  end

  # ============================================================================
  # Persistencia de estado
  # ============================================================================

  describe "persistencia de estado del socket" do
    test "el modo persiste al subir archivos", %{conn: conn, csv: csv} do
      {:ok, view, _} = live(conn, ~p"/live")
      view |> element("input[value='parallel']") |> render_click()
      upload_files(view, [csv])
      assert render(view) =~ "Mostrar Configuración Avanzada"
    end

    test "los archivos persisten al cambiar de modo", %{conn: conn, csv: csv} do
      {:ok, view, _} = live(conn, ~p"/live")
      upload_files(view, [csv])
      view |> element("input[value='parallel']") |> render_click()
      view |> element("input[value='sequential']") |> render_click()
      assert render(view) =~ csv.name
    end
  end
end
