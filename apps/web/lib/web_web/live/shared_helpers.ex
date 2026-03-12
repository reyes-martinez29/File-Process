defmodule WebWeb.SharedHelpers do
  @moduledoc """
  Helper functions shared across multiple LiveViews.

  This module contains common formatting and configuration helpers
  used by ResultsLive, ErrorsLive, and potentially other LiveViews.
  """

  @doc """
  Returns configuration map for status badges.

  ## Examples

      iex> WebWeb.SharedHelpers.status_badge_config(:ok)
      %{color: "emerald", icon: "✓", text: "Success"}
  """
  def status_badge_config(:ok), do: %{color: "emerald", icon: "✓", text: "Success"}
  def status_badge_config(:error), do: %{color: "rose", icon: "✕", text: "Error"}
  def status_badge_config(:partial), do: %{color: "amber", icon: "⚠", text: "Partial"}
  def status_badge_config(_), do: %{color: "slate", icon: "?", text: "Unknown"}

  @doc """
  Returns configuration map for file type badges.

  ## Examples

      iex> WebWeb.SharedHelpers.file_type_config(:csv)
      %{color: "indigo", icon: "📊", label: "CSV"}
  """
  def file_type_config(:csv), do: %{color: "indigo", icon: "📊", label: "CSV"}
  def file_type_config(:json), do: %{color: "amber", icon: "📄", label: "JSON"}
  def file_type_config(:xml), do: %{color: "green", icon: "📝", label: "XML"}
  def file_type_config(:log), do: %{color: "purple", icon: "📋", label: "LOG"}
  def file_type_config(_), do: %{color: "slate", icon: "❓", label: "UNKNOWN"}

  @doc """
  Formats duration in milliseconds to human-readable string.

  Shows milliseconds for values < 1000ms, otherwise shows seconds with 2 decimals.

  ## Examples

      iex> WebWeb.SharedHelpers.format_duration(500)
      "500ms"

      iex> WebWeb.SharedHelpers.format_duration(2500)
      "2.5s"
  """
  def format_duration(ms) when ms < 1000, do: "#{ms}ms"
  def format_duration(ms), do: "#{Float.round(ms / 1000, 2)}s"

  @doc """
  Formats error messages consistently.

  Handles various error formats:
  - Tuple with line number: {line, message}
  - Binary string: message
  - Other: inspect(value)

  ## Examples

      iex> WebWeb.SharedHelpers.format_error({10, "Invalid value"})
      "Line 10: Invalid value"

      iex> WebWeb.SharedHelpers.format_error("Something went wrong")
      "Something went wrong"
  """
  def format_error({line, msg}), do: "Line #{line}: #{msg}"
  def format_error(msg) when is_binary(msg), do: msg
  def format_error(other), do: inspect(other)
end
