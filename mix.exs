defmodule LazyDoc.MixProject do
  use Mix.Project

  def project do
    [
      app: :lazy_doc,
      version: "0.3.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A Mix task for documenting your projects with AI",
      package: package(),
      aliases: aliases(),
      name: "LazyDoc",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "base.ci": :test
      ],
      dialyzer: [
        check_plt: true,
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit, :mix]
      ]
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dotenv, "~> 3.0.0", only: [:dev, :test]},
      {:req, "~> 0.4.0"},
      {:jason, "~> 1.0"},
      ## Testing and converalls
      {:plug, "~> 1.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp aliases() do
    [
      "base.ci": [
        "deps.get",
        "compile --warnings-as-errors",
        "format",
        "credo --strict",
        "dialyzer --plt --force-check",
        "dialyzer --format github",
        "deps.unlock --check-unused",
        "test"
      ]
    ]
  end
end
