defmodule Confy.MixProject do
  @source_url "https://github.com/Qqwy/elixir_confy"
  use Mix.Project

  def project do
    [
      app: :confy,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env),
      description: description(),
      package: package(),
      source_url: @source_url,
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
      {:inch_ex, ">= 0.0.0", only: [:docs]},     # Inch CI documentation quality test.
    ]
  end

  defp elixirc_paths(_), do: ["lib"]

  defp description do
    """
    Comfortable, Explicit, Multi-Layered and Well-Documented configuration specifications
    """
  end

  defp package do
    [# These are the default files included in the package
      name: :confy,
      files: ["lib", "mix.exs", "README*", "LICENSE"],
      maintainers: ["Wiebe-Marten Wijnja/Qqwy"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
