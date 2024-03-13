defmodule Anthropix.MixProject do
  use Mix.Project

  def project do
    [
      app: :anthropix,
      name: "Anthropix",
      description: "Anthropix is an open-source Elixir client with interacting with Claude, Anthropic's powerful language model.",
      source_url: "https://github.com/lebrunel/anthropix",
      version: "0.0.1",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        main: "Anthropix"
      ],
      package: [
        name: "anthropix",
        files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
        licenses: ["Apache-2.0"],
        links: %{
          "GitHub" => "https://github.com/lebrunel/anthropix"
        }
      ]
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
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:plug, "~> 1.15", only: :test},
      {:req, "~> 0.4"},
      {:saxy, "~> 1.5"},
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_), do: ["lib"]
end
