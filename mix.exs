defmodule Noizu.Services.MixProject do
  use Mix.Project

  def project do
    [
      app: :noizu_labs_services,
      name: "NoizuLabs Services",
      version: "0.1.1",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      test_coverage: [
        summary: [
          threshold: 0
        ]
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]



  defp description() do
    "Long Lived Services Scaffolding libraries"
  end


  defp package() do
    [
      licenses: ["MIT"],
      links: %{
        project: "https://github.com/noizu-labs-scaffolding/services",
        noizu_labs: "https://github.com/noizu-labs",
        noizu_labs_ml: "https://github.com/noizu-labs-ml",
        noizu_labs_scaffolding: "https://github.com/noizu-labs-scaffolding",
        developer: "https://github.com/noizu"
      }
    ]
  end


  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      #applications: [:noizu_labs_services],
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:syn, "~> 3.3"},
      {:junit_formatter, "~> 3.3", only: [:test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]|> then(fn(deps) ->
      if Application.get_env(:noizu_labs_entities, :umbrella) do
        deps ++ [{:noizu_labs_core, in_umbrella: true }, {:noizu_labs_entities, in_umbrella: true }]
      else
        deps ++ [
          {:noizu_labs_entities,
            github: "noizu-labs-scaffolding/entities", branch: "develop", override: true},
        ]
      end
    end)
  end
end
