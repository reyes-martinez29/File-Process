defmodule WebWeb.ResultsComponents do
  @moduledoc """
  Reusable function components for Results and Errors LiveViews.
  """
  use Phoenix.Component

  @doc """
  Renders an empty state message when no files of a certain type were processed.

  ## Examples

      <.empty_state message="No CSV files were processed" />
  """
  attr :message, :string, required: true

  def empty_state(assigns) do
    ~H"""
    <div class="bg-slate-50 rounded-2xl p-8 text-center">
      <p class="text-slate-400 text-sm"><%= @message %></p>
    </div>
    """
  end

  @doc """
  Renders a metric card with label, value, and color scheme.

  ## Examples

      <.metric_card label="Total Sales" value="$1,234.56" color="emerald" />
      <.metric_card label="Total Users" value={@count} color="blue" class="col-span-2" />
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :color, :string, required: true, values: ~w(indigo amber green purple rose slate emerald blue)
  attr :class, :string, default: ""

  def metric_card(assigns) do
    {bg_classes, text_classes} = metric_card_classes(assigns.color)
    assigns = assign(assigns, bg_classes: bg_classes, text_classes: text_classes)

    ~H"""
    <div class={["rounded-xl p-4", @bg_classes, @class]}>
      <p class={["text-xs font-bold mb-1", @text_classes]}><%= @label %></p>
      <p class={["text-2xl font-black", @text_classes]}>
        <%= @value %>
      </p>
    </div>
    """
  end

  defp metric_card_classes("indigo"), do: {"bg-indigo-50 border border-indigo-100", "text-indigo-600"}
  defp metric_card_classes("amber"), do: {"bg-amber-50 border border-amber-100", "text-amber-600"}
  defp metric_card_classes("green"), do: {"bg-green-50 border border-green-100", "text-green-600"}
  defp metric_card_classes("purple"), do: {"bg-purple-50 border border-purple-100", "text-purple-600"}
  defp metric_card_classes("rose"), do: {"bg-rose-50 border border-rose-100", "text-rose-600"}
  defp metric_card_classes("slate"), do: {"bg-slate-50 border border-slate-100", "text-slate-600"}
  defp metric_card_classes("emerald"), do: {"bg-emerald-50 border border-emerald-100", "text-emerald-600"}
  defp metric_card_classes("blue"), do: {"bg-blue-50 border border-blue-100", "text-blue-600"}

  @doc """
  Renders a summary card for the executive summary section.

  ## Examples

      <.summary_card icon="📂" value={100} label="Files" />
      <.summary_card icon="⏱️" value="1234ms" label="Total Time" />
      <.summary_card icon="✅" value="98%" label="Success Rate" variant="success" />
  """
  attr :icon, :string, required: true
  attr :value, :any, required: true
  attr :label, :string, required: true
  attr :variant, :string, default: "default"

  def summary_card(assigns) do
    ~H"""
    <div class={[
      "p-6 rounded-2xl relative overflow-hidden group",
      @variant == "success" && "bg-emerald-50 border border-emerald-100",
      @variant == "default" && "bg-slate-50 border border-slate-100"
    ]}>
      <div class={[
        "absolute -right-2 -bottom-2 text-6xl transition-transform group-hover:scale-110",
        @variant == "success" && "opacity-10",
        @variant == "default" && "opacity-5"
      ]}>
        <%= @icon %>
      </div>
      <p class={[
        "text-3xl font-black",
        @variant == "success" && "text-emerald-600",
        @variant == "default" && "text-slate-800"
      ]}>
        <%= @value %>
      </p>
      <p class={[
        "text-xs font-bold uppercase tracking-tighter",
        @variant == "success" && "text-emerald-500",
        @variant == "default" && "text-slate-400"
      ]}>
        <%= @label %>
      </p>
    </div>
    """
  end

  @doc """
  Renders a file result card with header and custom metrics content via slot.

  The slot receives the result assign so metrics can be accessed inside.
  Use `grid_layout: false` for LOG files which need custom layout.

  ## Examples

      <.file_result_card result={result} color="indigo" icon_path="M9 17v-2m3 2v-4...">
        <.metric_card label="Sales" value={result.metrics.total_sales} color="emerald" />
      </.file_result_card>

      <.file_result_card result={result} color="purple" icon_path="..." grid_layout={false}>
        <div class="space-y-4">
          <%!-- Custom LOG structure --%>
        </div>
      </.file_result_card>
  """
  attr :result, :map, required: true
  attr :color, :string, required: true, values: ~w(indigo amber green purple)
  attr :icon_path, :string, required: true
  attr :grid_layout, :boolean, default: true
  slot :inner_block, required: true

  def file_result_card(assigns) do
    {header_classes, icon_classes} = file_card_classes(assigns.color)
    assigns = assign(assigns, header_classes: header_classes, icon_classes: icon_classes)

    ~H"""
    <div class="bg-white rounded-2xl border border-slate-200 overflow-hidden">
      <%!-- File header --%>
      <div class={["px-6 py-4", @header_classes]}>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class={["p-2 rounded-lg", @icon_classes]}>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d={@icon_path}
                />
              </svg>
            </div>
            <div>
              <h3 class="font-bold text-slate-800"><%= @result.filename %></h3>
              <p class="text-xs text-slate-500">
                <%= @result.lines_processed %> records • <%= @result.duration_ms %>ms
              </p>
            </div>
          </div>
          <.status_badge status={@result.status} />
        </div>
      </div>

      <%!-- Metrics content --%>
      <%= if @result.status != :error do %>
        <div class="p-6">
          <%= if @grid_layout do %>
            <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
              <%= render_slot(@inner_block, @result) %>
            </div>
          <% else %>
            <%= render_slot(@inner_block, @result) %>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp file_card_classes("indigo"), do: {"bg-gradient-to-r from-indigo-50 to-indigo-50 border-b border-indigo-100", "bg-indigo-100 text-indigo-600"}
  defp file_card_classes("amber"), do: {"bg-gradient-to-r from-amber-50 to-amber-50 border-b border-amber-100", "bg-amber-100 text-amber-600"}
  defp file_card_classes("green"), do: {"bg-gradient-to-r from-green-50 to-green-50 border-b border-green-100", "bg-green-100 text-green-600"}
  defp file_card_classes("purple"), do: {"bg-gradient-to-r from-purple-50 to-purple-50 border-b border-purple-100", "bg-purple-100 text-purple-600"}

  @doc """
  Renders a status badge for file processing status.

  ## Examples

      <.status_badge status={:ok} />
      <.status_badge status={:error} />
  """
  attr :status, :atom, required: true

  def status_badge(assigns) do
    {badge_classes, icon, text} = status_badge_classes(assigns.status)
    assigns = assigns |> assign(:badge_classes, badge_classes) |> assign(:icon, icon) |> assign(:text, text)

    ~H"""
    <span class={["px-3 py-1 rounded-full text-xs font-bold", @badge_classes]}>
      <%= @icon %> <%= @text %>
    </span>
    """
  end

  defp status_badge_classes(:ok), do: {"bg-emerald-100 text-emerald-700", "✓", "Success"}
  defp status_badge_classes(:error), do: {"bg-rose-100 text-rose-700", "✕", "Error"}
  defp status_badge_classes(:partial), do: {"bg-amber-100 text-amber-700", "⚠", "Partial"}
  defp status_badge_classes(_), do: {"bg-slate-100 text-slate-700", "?", "Unknown"}
end
