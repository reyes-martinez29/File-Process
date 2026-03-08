defmodule WebWeb.BenchmarkLive do
  use WebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Benchmark")
     |> assign(:benchmark_data, nil)
     |> assign(:processing, false)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_params(%{"id" => benchmark_id}, _uri, socket) do
    # Fetch files from BenchmarkStore
    case Web.BenchmarkStore.get(benchmark_id) do
      {:ok, files} ->
        # Start processing immediately on mount
        send(self(), {:start_benchmark, files, benchmark_id})
        {:noreply, assign(socket, processing: true, benchmark_id: benchmark_id)}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Benchmark files not found or expired")
         |> push_navigate(to: ~p"/")}
    end
  end

  def handle_params(_params, _uri, socket) do
    # No benchmark ID provided, redirect to home
    {:noreply,
     socket
     |> put_flash(:error, "No benchmark ID provided")
     |> push_navigate(to: ~p"/")}
  end

  @impl true
  def handle_info({:start_benchmark, files, benchmark_id}, socket) do
    # Process benchmark in background task
    parent = self()

    Task.start(fn ->
      # Extract file paths from file info maps
      temp_files = Enum.map(files, & &1["path"])

      # Run benchmark
      opts = [benchmark: true, verbose: false]
      resultado = FProcess.process_files(temp_files, opts)

      # Clean up files from BenchmarkStore (this also deletes files from filesystem)
      Web.BenchmarkStore.delete(benchmark_id)

      # Send results back to LiveView
      send(parent, {:benchmark_complete, resultado})
    end)

    {:noreply, socket}
  end

  def handle_info({:benchmark_complete, {:ok, reporte}}, socket) do
    {:noreply,
     socket
     |> assign(:benchmark_data, reporte.benchmark_data)
     |> assign(:processing, false)}
  end

  def handle_info({:benchmark_complete, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:error, reason)
     |> assign(:processing, false)}
  end
end
