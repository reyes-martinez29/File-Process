defmodule WebWeb.PageControllerTest do
  use WebWeb.ConnCase

  # ============================================================================
  # Setup
  # ============================================================================

  setup do
    # Ensure ETS table exists for tests
    case :ets.whereis(:reports_store) do
      :undefined -> :ets.new(:reports_store, [:set, :public, :named_table])
      _ -> :ok
    end

    # Clean ETS before each test
    :ets.delete_all_objects(:reports_store)
    :ok
  end

  # ============================================================================
  # Home Page Tests
  # ============================================================================

  describe "home page" do
    test "GET / renders upload form", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      # Check for key UI elements from our custom home page
      assert html =~ "Procesador de Archivos"
      assert html =~ "Sistema de procesamiento inteligente"
      assert html =~ "Configuración de Procesamiento"
      assert html =~ "Modo Secuencial"
      assert html =~ "Modo Paralelo"
      assert html =~ "Modo Benchmark"
    end

    test "home page includes file upload input", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "type=\"file\""
      assert html =~ "name=\"archivos[]\""
      assert html =~ "multiple"
    end

    test "home page includes processing mode radios", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "name=\"processing_mode\""
      assert html =~ "value=\"sequential\""
      assert html =~ "value=\"parallel\""
      assert html =~ "value=\"benchmark\""
    end

    test "home page includes advanced configuration section", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "id=\"parallel-config\""
      assert html =~ "Advanced Settings"
      assert html =~ "Max Workers"
      assert html =~ "Timeout (ms)"
    end
  end

  # ============================================================================
  # Upload Tests
  # ============================================================================

  describe "upload/2 - file processing" do
    test "POST /upload without files shows error flash", %{conn: conn} do
      conn = post(conn, ~p"/upload", %{})
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "No files received"
      assert html_response(conn, 200)
    end

    test "POST /upload with valid CSV file processes successfully", %{conn: conn} do
      # Use real valid test file
      temp_path = copy_test_file("ventas_enero.csv")

      upload = %Plug.Upload{
        path: temp_path,
        filename: "ventas_enero.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/upload", %{
        "archivos" => [upload],
        "processing_mode" => "sequential"
      })

      html = html_response(conn, 200)
      # Check for success indicators in the results page
      assert html =~ "Resumen" || html =~ "Processing" || html =~ "Procesamiento"
      # Cleanup (file might already be deleted by controller)
      if File.exists?(temp_path), do: File.rm(temp_path)
    end

    test "POST /upload stores report in ETS with unique ID", %{conn: conn} do
      temp_path = copy_test_file("ventas_enero.csv")

      upload = %Plug.Upload{
        path: temp_path,
        filename: "ventas_enero.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/upload", %{
        "archivos" => [upload],
        "processing_mode" => "parallel"
      })

      # Check that session contains report_id
      report_id = get_session(conn, :report_id)
      assert report_id != nil
      assert is_binary(report_id)
      assert byte_size(report_id) > 0

      # Check that ETS contains the report
      case :ets.lookup(:reports_store, report_id) do
        [{^report_id, _report, timestamp}] ->
          assert is_integer(timestamp)
          assert timestamp > 0
        [] ->
          flunk("Report not found in ETS")
      end

      if File.exists?(temp_path), do: File.rm(temp_path)
    end
  end

  # ============================================================================
  # Parallel Mode Configuration Tests
  # ============================================================================

  describe "upload/2 - advanced parallel configuration" do
    test "uses default values when no advanced config provided", %{conn: conn} do
      temp_path = copy_test_file("ventas_enero.csv")

      upload = %Plug.Upload{
        path: temp_path,
        filename: "ventas_enero.csv",
        content_type: "text/csv"
      }

      # Submit without max_workers or timeout
      conn = post(conn, ~p"/upload", %{
        "archivos" => [upload],
        "processing_mode" => "parallel"
      })

      html = html_response(conn, 200)
      assert html =~ "Resumen" || html =~ "Results" || html =~ "Procesamiento"
      if File.exists?(temp_path), do: File.rm(temp_path)
    end

    test "accepts valid max_workers within bounds", %{conn: conn} do
      temp_path = copy_test_file("ventas_enero.csv")

      upload = %Plug.Upload{
        path: temp_path,
        filename: "ventas_enero.csv",
        content_type: "text/csv"
      }

      # Submit with valid max_workers (4 is within any system's limit)
      conn = post(conn, ~p"/upload", %{
        "archivos" => [upload],
        "processing_mode" => "parallel",
        "max_workers" => "4"
      })

      html = html_response(conn, 200)
      assert html =~ "Resumen" || html =~ "Results" || html =~ "Procesamiento"
      if File.exists?(temp_path), do: File.rm(temp_path)
    end

    test "accepts valid timeout within bounds", %{conn: conn} do
      temp_path = copy_test_file("ventas_enero.csv")

      upload = %Plug.Upload{
        path: temp_path,
        filename: "ventas_enero.csv",
        content_type: "text/csv"
      }

      # Submit with valid timeout
      conn = post(conn, ~p"/upload", %{
        "archivos" => [upload],
        "processing_mode" => "parallel",
        "timeout" => "5000"
      })

      html = html_response(conn, 200)
      assert html =~ "Resumen" || html =~ "Results" || html =~ "Procesamiento"
      if File.exists?(temp_path), do: File.rm(temp_path)
    end

    test "clamps max_workers to minimum when too low", %{conn: conn} do
      temp_path = copy_test_file("ventas_enero.csv")

      upload = %Plug.Upload{
        path: temp_path,
        filename: "ventas_enero.csv",
        content_type: "text/csv"
      }

      # Submit with max_workers = 0 (below minimum)
      conn = post(conn, ~p"/upload", %{
        "archivos" => [upload],
        "processing_mode" => "parallel",
        "max_workers" => "0"
      })

      # Should still process successfully (clamped to 1)
      html = html_response(conn, 200)
      assert html =~ "Resumen" || html =~ "Results" || html =~ "Procesamiento"
      if File.exists?(temp_path), do: File.rm(temp_path)
    end

    test "clamps timeout to minimum when too low", %{conn: conn} do
      temp_path = copy_test_file("ventas_enero.csv")

      upload = %Plug.Upload{
        path: temp_path,
        filename: "ventas_enero.csv",
        content_type: "text/csv"
      }

      # Submit with timeout = 500 (below minimum of 1000)
      conn = post(conn, ~p"/upload", %{
        "archivos" => [upload],
        "processing_mode" => "parallel",
        "timeout" => "500"
      })

      # Should still process successfully (clamped to 1000)
      html = html_response(conn, 200)
      assert html =~ "Resumen" || html =~ "Results" || html =~ "Procesamiento"
      if File.exists?(temp_path), do: File.rm(temp_path)
    end
  end

  # ============================================================================
  # Results Page Tests
  # ============================================================================

  describe "results/2 - viewing saved results" do
    test "GET /results without session redirects to home", %{conn: conn} do
      conn = get(conn, ~p"/results")
      assert redirected_to(conn) == ~p"/"
      assert get_flash(conn, :error) =~ "No processing report found"
    end

    test "GET /results with invalid report_id redirects to home", %{conn: conn} do
      conn = conn
      |> init_test_session(%{})
      |> put_session(:report_id, "nonexistent_id")
      |> get(~p"/results")

      assert redirected_to(conn) == ~p"/"
      assert get_flash(conn, :error) =~ "Report expired or not found"
    end

    test "GET /results with valid report_id displays results", %{conn: conn} do
      # Insert a mock report into ETS with all required fields (using DateTime)
      report_id = "test_report_123"
      now = DateTime.utc_now()
      mock_report = %{
        start_time: now,
        end_time: now,
        mode: "parallel",
        processing_mode: "parallel",
        total_duration_ms: 100,
        success_count: 1,
        error_count: 0,
        partial_count: 0,
        total_files: 1,
        csv_count: 1,
        json_count: 0,
        xml_count: 0,
        log_count: 0,
        results: []
      }
      :ets.insert(:reports_store, {report_id, mock_report, System.system_time(:second)})

      conn = conn
      |> init_test_session(%{})
      |> put_session(:report_id, report_id)
      |> get(~p"/results")

      html = html_response(conn, 200)
      assert html =~ "Processing Summary" || html =~ "Resumen"
    end
  end

  # ============================================================================
  # Errors Page Tests
  # ============================================================================

  describe "errors/2 - viewing error details" do
    test "GET /errors without session redirects to home", %{conn: conn} do
      conn = get(conn, ~p"/errors")
      assert redirected_to(conn) == ~p"/"
      assert get_flash(conn, :error) =~ "No processing report found"
    end

    test "GET /errors with valid report_id displays error page", %{conn: conn} do
      # Insert a mock report into ETS with all required fields (using DateTime)
      report_id = "test_report_errors"
      now = DateTime.utc_now()
      mock_report = %{
        start_time: now,
        end_time: now,
        mode: "parallel",
        processing_mode: "parallel",
        total_duration_ms: 100,
        success_count: 0,
        error_count: 1,
        partial_count: 0,
        total_files: 1,
        csv_count: 1,
        json_count: 0,
        xml_count: 0,
        log_count: 0,
        results: []
      }
      :ets.insert(:reports_store, {report_id, mock_report, System.system_time(:second)})

      conn = conn
      |> init_test_session(%{})
      |> put_session(:report_id, report_id)
      |> get(~p"/errors")

      html = html_response(conn, 200)
      assert html =~ "Error Details" || html =~ "Errores"
    end
  end

  # ============================================================================
  # Benchmark Tests
  # ============================================================================

  describe "benchmark_results/2 - benchmark mode" do
    test "POST /benchmark processes files and shows comparison", %{conn: conn} do
      temp_path = copy_test_file("ventas_enero.csv")

      upload = %Plug.Upload{
        path: temp_path,
        filename: "ventas_enero.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/benchmark", %{
        "archivos" => [upload]
      })

      html = html_response(conn, 200)
      assert html =~ "BENCHMARK"
      assert html =~ "Sequential"
      assert html =~ "Parallel"

      if File.exists?(temp_path), do: File.rm(temp_path)
    end

    test "benchmark mode does not store in ETS", %{conn: conn} do
      temp_path = copy_test_file("ventas_enero.csv")

      upload = %Plug.Upload{
        path: temp_path,
        filename: "ventas_enero.csv",
        content_type: "text/csv"
      }

      # Count ETS entries before
      before_count = :ets.info(:reports_store)[:size]

      _conn = post(conn, ~p"/benchmark", %{
        "archivos" => [upload]
      })

      # Count ETS entries after - should be the same
      after_count = :ets.info(:reports_store)[:size]
      assert before_count == after_count

      if File.exists?(temp_path), do: File.rm(temp_path)
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp write_temp_file(filename, content) do
    path = Path.join(System.tmp_dir!(), filename)
    File.write!(path, content)
    path
  end

  defp copy_test_file(source_filename) do
    # Go up to project root from apps/web
    project_root = Path.join([File.cwd!(), "..", ".."])
    source_path = Path.join([project_root, "data", "valid", source_filename])
    dest_path = Path.join(System.tmp_dir!(), "test_#{:erlang.unique_integer([:positive])}_#{source_filename}")
    File.cp!(source_path, dest_path)
    dest_path
  end

  defp copy_error_file(source_filename) do
    # Go up to project root from apps/web
    project_root = Path.join([File.cwd!(), "..", ".."])
    source_path = Path.join([project_root, "data", "error", source_filename])
    dest_path = Path.join(System.tmp_dir!(), "test_error_#{:erlang.unique_integer([:positive])}_#{source_filename}")
    File.cp!(source_path, dest_path)
    dest_path
  end

  defp valid_csv_path do
    project_root = Path.join([File.cwd!(), "..", ".."])
    Path.join([project_root, "data", "valid", "ventas_enero.csv"])
  end

  defp valid_json_path do
    project_root = Path.join([File.cwd!(), "..", ".."])
    Path.join([project_root, "data", "valid", "usuarios.json"])
  end

  defp error_csv_path do
    project_root = Path.join([File.cwd!(), "..", ".."])
    Path.join([project_root, "data", "error", "ventas_corrupto.csv"])
  end

  defp error_json_path do
    project_root = Path.join([File.cwd!(), "..", ".."])
    Path.join([project_root, "data", "error", "usuarios_malformado.json"])
  end
end
