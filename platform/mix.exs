defmodule Platform.MixProject do
  use Mix.Project

  def project do
    [
      app: :platform,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      escript: [main_module: Platform.CLI]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Platform.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end

  defp aliases do
    [
      demo: "run --no-halt lib/platform/demo.ex"
    ]
  end
end
