defmodule LazyDoc.MixProject do
  use Mix.Project

  def project do
    [
      app: :lazy_doc,
      version: "0.2.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A Mix task for documenting your projects with AI",
      package: package()
    ]
  end

  defp package() do
    [
      name: "lazy_doc",
      maintainers: ["Pepe Marquez"],
      licenses: ["MIT"],
      links: %{"GitHub" => github_link()}
    ]
  end

  defp github_link() do
    "https://github.com/pxp9/lazy_doc"
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {LazyDoc.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dotenv, "~> 3.0.0", only: [:dev]},
      {:req, "~> 0.4.0"},
      {:jason, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
