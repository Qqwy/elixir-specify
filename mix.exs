defmodule Specify.MixProject do
  @source_url "https://github.com/Qqwy/elixir_specify"
  use Mix.Project

  def project do
    [
      app: :specify,
      version: "0.4.4",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      source_url: @source_url,
      docs: docs()
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
      {:ex_doc, "~> 0.19", only: [:docs], runtime: false},
      # Inch CI documentation quality test.
      {:inch_ex, ">= 0.0.0", only: [:docs]},
      {:stream_data, "~> 0.1", only: :test}
    ]
  end

  defp elixirc_paths(_), do: ["lib"]

  defp description do
    """
    Comfortable, Explicit, Multi-Layered and Well-Documented Specifications for all your configurations, settings and options
    """
  end

  defp package do
    # These are the default files included in the package
    [
      name: :specify,
      files: ["lib", "mix.exs", "README*", "LICENSE"],
      maintainers: ["Wiebe-Marten Wijnja/Qqwy"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "brand/logo-thicklines-25percent.png",
      extras: ["README.md"]
    ]
  end
end
