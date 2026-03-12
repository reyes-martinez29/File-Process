defmodule WebWeb.PageLiveTest do
  use WebWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  # ============================================================================
  # Helpers
  # ============================================================================

  defp copy_test_file(filename) do
    project_root = Path.join([File.cwd!(), "..", ".."])
    source_path = Path.join([project_root, "data", "valid", filename])

    dest_path =
      Path.join(
        System.tmp_dir!(),
        "test_#{:erlang.unique_integer([:positive])}_#{filename}"
      )

    File.cp!(source_path, dest_path)
    dest_path
  end

  # Uploads a file to the LiveView completing 100% progress.
  # Size MUST match byte_size(content) — LiveView validates this.
  defp upload_and_complete(view, path, filename, content_type \\ "text/csv") do
    content = File.read!(path)

    file = %{
      last_modified: :os.system_time(:millisecond),
      name: filename,
      content: content,
      size: byte_size(content),
      type: content_type
    }

    input = file_input(view, "#upload-form", :archivos, [file])
    render_upload(input, filename, 100)
  end

  # Reads socket assigns directly from the LiveView process
  defp socket_assigns(view) do
    :sys.get_state(view.pid).socket.assigns
  end

  # Reads the flash from the LiveView socket
  defp flash(view) do
    socket_assigns(view).flash
  end

  # push_navigate in LiveView 1.1.x stops the view process.
  # Monitor BEFORE calling the function to avoid missing the :DOWN message.
  defp assert_navigated_to(view, expected_prefix, fun) do
    ref = Process.monitor(view.pid)
    fun.()

    receive do
      {:DOWN, ^ref, :process, _pid, {:shutdown, {:redirect, %{to: path}}}} ->
        assert path =~ expected_prefix
        path

      {:DOWN, ^ref, :process, _pid, {:shutdown, %{to: path}}} ->
        assert path =~ expected_prefix
        path

      {:DOWN, ^ref, :process, _pid, {:redirect, %{to: path}}} ->
        assert path =~ expected_prefix
        path

      {:DOWN, ^ref, :process, _pid, {:shutdown, {:live_redirect, %{to: path}}}} ->
        assert path =~ expected_prefix
        path

      {:DOWN, ^ref, :process, _pid, reason} ->
        flunk("El proceso terminó con razón inesperada: #{inspect(reason)}")
    after
      5000 ->
        flunk("Timeout esperando redirect a #{expected_prefix}")
    end
  end

  # ============================================================================
  # Mount / Initial Render
  # ============================================================================

  describe "mount y render inicial" do
    test "renderiza la página de inicio correctamente", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live/home")

      assert html =~ "Procesador de Archivos"
      assert html =~ "Sistema de procesamiento inteligente"
      assert html =~ "Configuración de Procesamiento"
    end

    test "muestra los tres modos de procesamiento", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live/home")

      assert html =~ "Modo Secuencial"
      assert html =~ "Modo Paralelo"
      assert html =~ "Modo Benchmark"
    end

    test "el modo secuencial está seleccionado por defecto", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live/home")

      assert html =~ ~s(value="sequential")
      assert html =~ ~s(checked="")
    end

    test "el panel avanzado NO es visible al inicio", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live/home")

      refute html =~ "Max Workers"
      refute html =~ "Timeout (ms)"
    end

    test "el botón de submit está presente", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live/home")

      assert html =~ "Comenzar Procesamiento"
    end

    test "la barra de progreso NO es visible al inicio", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live/home")

      refute html =~ "Analizando archivos..."
    end

    test "el aside de vista previa muestra estado vacío", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/live/home")

      assert html =~ "Vista Previa"
      assert html =~ "Ningún archivo seleccionado aún"
    end
  end

  # ============================================================================
  # Event: set_mode
  # ============================================================================

  describe "evento set_mode" do
    test "cambia a modo paralelo", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      html = render_click(view, "set_mode", %{"mode" => "parallel"})

      assert html =~ "Modo Paralelo"
    end

    test "modo parallel muestra toggle de configuración avanzada", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      html = render_click(view, "set_mode", %{"mode" => "parallel"})

      assert html =~ "Mostrar Configuración Avanzada"
    end

    test "cambia a modo benchmark", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      html = render_click(view, "set_mode", %{"mode" => "benchmark"})

      assert html =~ "Modo Benchmark"
    end

    test "volver a modo secuencial oculta el toggle avanzado", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_click(view, "set_mode", %{"mode" => "parallel"})
      html = render_click(view, "set_mode", %{"mode" => "sequential"})

      refute html =~ "Mostrar Configuración Avanzada"
    end

    test "actualiza :processing_mode en el socket", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_click(view, "set_mode", %{"mode" => "parallel"})

      assert socket_assigns(view).processing_mode == "parallel"
    end

    test "cambiar de modo limpia :no_files_error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_submit(view, "process_files", %{})
      assert socket_assigns(view).no_files_error == true

      render_click(view, "set_mode", %{"mode" => "parallel"})

      assert socket_assigns(view).no_files_error == false
    end
  end

  # ============================================================================
  # Event: toggle_advanced
  # ============================================================================

  describe "evento toggle_advanced" do
    test "muestra el panel avanzado al activarlo en modo parallel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_click(view, "set_mode", %{"mode" => "parallel"})
      html = render_click(view, "toggle_advanced", %{})

      assert html =~ "Max Workers"
      assert html =~ "Timeout (ms)"
    end

    test "oculta el panel avanzado al desactivarlo", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_click(view, "set_mode", %{"mode" => "parallel"})
      render_click(view, "toggle_advanced", %{})
      html = render_click(view, "toggle_advanced", %{})

      refute html =~ "Max Workers"
      refute html =~ "Timeout (ms)"
    end

    test ":show_advanced alterna correctamente en el socket", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      assert socket_assigns(view).show_advanced == false

      render_click(view, "set_mode", %{"mode" => "parallel"})
      render_click(view, "toggle_advanced", %{})
      assert socket_assigns(view).show_advanced == true

      render_click(view, "toggle_advanced", %{})
      assert socket_assigns(view).show_advanced == false
    end
  end

  # ============================================================================
  # Event: validate
  # ============================================================================

  describe "evento validate" do
    test "limpia :no_files_error en el socket", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_submit(view, "process_files", %{})
      assert socket_assigns(view).no_files_error == true

      render_change(view, "validate", %{})
      assert socket_assigns(view).no_files_error == false
    end

    test "el HTML ya no muestra el error tras validate", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_submit(view, "process_files", %{})
      assert render(view) =~ "Selecciona al menos un archivo"

      html = render_change(view, "validate", %{})
      refute html =~ "Selecciona al menos un archivo"
    end
  end

  # ============================================================================
  # Event: process_files — no files
  # ============================================================================

  describe "process_files sin archivos" do
    test "activa :no_files_error en el socket", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_submit(view, "process_files", %{})

      assert socket_assigns(view).no_files_error == true
    end

    test "muestra el mensaje de error inline en el HTML", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      html = render_submit(view, "process_files", %{})

      assert html =~ "Selecciona al menos un archivo antes de continuar"
    end

    test "pone el flash de error en el socket", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_submit(view, "process_files", %{})

      assert flash(view)["error"] =~ "Primero tienes que seleccionar al menos 1 archivo"
    end

    test ":processing permanece en false", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_submit(view, "process_files", %{})

      assert socket_assigns(view).processing == false
    end
  end

  # ============================================================================
  # Event: process_benchmark — no files
  # ============================================================================

  describe "process_benchmark sin archivos" do
    test "activa :no_files_error en el socket", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_click(view, "set_mode", %{"mode" => "benchmark"})
      render_submit(view, "process_benchmark", %{})

      assert socket_assigns(view).no_files_error == true
    end

    test "muestra el mensaje de error inline en el HTML", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_click(view, "set_mode", %{"mode" => "benchmark"})
      html = render_submit(view, "process_benchmark", %{})

      assert html =~ "Selecciona al menos un archivo antes de continuar"
    end

    test "pone el flash de error en el socket", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_click(view, "set_mode", %{"mode" => "benchmark"})
      render_submit(view, "process_benchmark", %{})

      assert flash(view)["error"] =~ "Primero tienes que seleccionar al menos 1 archivo"
    end
  end

  # ============================================================================
  # Event: cancel_upload
  # ============================================================================

  describe "cancel_upload" do
    test "elimina el entry del socket tras cancelar", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      path = copy_test_file("ventas_enero.csv")
      upload_and_complete(view, path, "ventas_enero.csv")

      entries = socket_assigns(view).uploads.archivos.entries
      assert length(entries) == 1

      ref = hd(entries).ref
      render_click(view, "cancel_upload", %{"ref" => ref})

      assert socket_assigns(view).uploads.archivos.entries == []

      File.rm(path)
    end
  end

  # ============================================================================
  # Processing with real files — redirect via monitor
  # ============================================================================

  describe "process_files con archivo válido (secuencial)" do
    test "redirige a /live/results tras procesar exitosamente", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      path = copy_test_file("ventas_enero.csv")
      upload_and_complete(view, path, "ventas_enero.csv")

      assert_navigated_to(view, "/live/results", fn ->
        render_submit(view, "process_files", %{"processing_mode" => "sequential"})
      end)

      File.rm(path)
    end

    test "guarda el reporte en ReportStore", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      path = copy_test_file("ventas_enero.csv")
      upload_and_complete(view, path, "ventas_enero.csv")

      redirect_path =
        assert_navigated_to(view, "/live/results", fn ->
          render_submit(view, "process_files", %{"processing_mode" => "sequential"})
        end)

      report_id = redirect_path |> String.split("id=") |> List.last()
      assert {:ok, _reporte} = Web.ReportStore.get(report_id)

      File.rm(path)
    end
  end

  describe "process_files modo paralelo" do
    test "redirige a /live/results con max_workers válido", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_click(view, "set_mode", %{"mode" => "parallel"})

      path = copy_test_file("ventas_enero.csv")
      upload_and_complete(view, path, "ventas_enero.csv")

      assert_navigated_to(view, "/live/results", fn ->
        render_submit(view, "process_files", %{
          "processing_mode" => "parallel",
          "max_workers" => "4"
        })
      end)

      File.rm(path)
    end

    test "max_workers = 0 se clampea a 1 y procesa correctamente", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_click(view, "set_mode", %{"mode" => "parallel"})

      path = copy_test_file("ventas_enero.csv")
      upload_and_complete(view, path, "ventas_enero.csv")

      assert_navigated_to(view, "/live/results", fn ->
        render_submit(view, "process_files", %{
          "processing_mode" => "parallel",
          "max_workers" => "0"
        })
      end)

      File.rm(path)
    end
  end

  describe "process_benchmark con archivo válido" do
    test "redirige a /live/benchmark tras preparar archivos", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_click(view, "set_mode", %{"mode" => "benchmark"})

      path = copy_test_file("ventas_enero.csv")
      upload_and_complete(view, path, "ventas_enero.csv")

      assert_navigated_to(view, "/live/benchmark", fn ->
        render_submit(view, "process_benchmark", %{})
      end)

      File.rm(path)
    end

    test "guarda los archivos en BenchmarkStore", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/live/home")

      render_click(view, "set_mode", %{"mode" => "benchmark"})

      path = copy_test_file("ventas_enero.csv")
      upload_and_complete(view, path, "ventas_enero.csv")

      redirect_path =
        assert_navigated_to(view, "/live/benchmark", fn ->
          render_submit(view, "process_benchmark", %{})
        end)

      bench_id = redirect_path |> String.split("id=") |> List.last()
      assert {:ok, archivos} = Web.BenchmarkStore.get(bench_id)
      assert length(archivos) == 1

      File.rm(path)
    end
  end
end
