defmodule FProcess.MixProject do
  use Mix.Project

  def project do
    [
      app: :core,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()  # ← Agregamos configuración de escript
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_csv, "~> 1.2"},
      {:jason, "~> 1.4"},
      {:sweet_xml, "~> 0.7.4"}
    ]
  end

  # Configuración para generar ejecutable
  defp escript do
    [
      main_module: FProcess.CLI,
      name: "fprocess"
    ]
  end
end
