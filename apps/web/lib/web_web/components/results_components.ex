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
  attr :color, :string, required: true
  attr :class, :string, default: ""

  def metric_card(assigns) do
    ~H"""
    <div class={"bg-#{@color}-50 rounded-xl p-4 border border-#{@color}-100 #{@class}"}>
      <p class={"text-xs text-#{@color}-600 font-bold mb-1"}><%= @label %></p>
      <p class={"text-2xl font-black text-#{@color}-700"}>
        <%= @value %>
      </p>
    </div>
    """
  end

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
end
