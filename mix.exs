defmodule Bonfire.Data.Assort.MixProject do
  use Mix.Project

  def project do
    [
      app: :bonfire_data_assort,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      description:
        "Database models for tags, categories, and otherwise linked or ranked items in the bonfire ecosystem",
      homepage_url: "https://github.com/bonfire-networks/bonfire_data_assort",
      source_url: "https://github.com/bonfire-networks/bonfire_data_assort",
      package: [
        licenses: ["MPL 2.0"],
        links: %{
          "Repository" =>
            "https://github.com/bonfire-networks/bonfire_data_assort",
          "Hexdocs" => "https://hexdocs.pm/bonfire_data_assort"
        }
      ],
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      deps: [
        {:pointers, "~> 0.5.1"},
        {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
        {:ecto_ranked, "~> 0.5.0"}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
