defmodule Snmp.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/jeanparpaillon/elixir-snmp"

  def project do
    [
      app: :elixir_snmp,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: dialyzer(),
      preferred_cli_env: %{
        docs: :docs,
        "hex.publish": :docs,
        "hex.build": :docs
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia, :snmp, :public_key]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:stream_data, "~> 0.5", only: [:test]},
      {:ex_doc, "~> 0.23", only: [:docs], runtime: false},
      {:dialyxir, "1.0.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.11"},
      {:jason, ">= 0.0.0"},
      {:ecto, "~> 3.6"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Jean Parpaillon"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(.formatter.exs mix.exs README.md CHANGELOG.md lib)
    ]
  end

  defp description do
    "SNMP tooling for elixir"
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html"],
      groups_for_modules: [
        "Agent building": [Snmp.Agent, Snmp.Agent.DSL, Snmp.Transport],
        "MIBs tooling": [Snmp.Instrumentation, Snmp.Instrumentation.Generic, Snmp.Mib],
        "Standard MIBs": [
          Snmp.Mib.Community,
          Snmp.Mib.Framework,
          Snmp.Mib.Standard,
          Snmp.Mib.UserBasedSm,
          Snmp.Mib.Vacm
        ],
        Misc: [Snmp.Compiler]
      ]
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: "dialyzer.ignore-warnings",
      plt_add_apps: [:mix]
    ]
  end
end
