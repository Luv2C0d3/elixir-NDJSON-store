defmodule SimpleISAM.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/pierrejacomet/simple_isam"

  def project do
    [
      app: :simple_isam,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "SimpleISAM",
      source_url: @source_url
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
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    A simple ISAM-like store backed by NDJSON files and ETS tables.
    Provides fast O(1) lookups through in-memory indexing while maintaining file persistence.
    Ideal for small to medium-sized datasets that need both quick access and durability.
    """
  end

  defp package do
    [
      name: "simple_isam",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE* CHANGELOG*),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
