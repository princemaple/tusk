defmodule Tusk.MixProject do
  use Mix.Project

  def project do
    [
      app: :tusk,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      name: "Tusk",
      description: description(),
      package: package(),
      source_url: "https://github.com/princemaple/tusk",
      homepage_url: "https://github.com/princemaple/tusk",
      docs: [
        main: "Tusk",
        canonical: "http://hexdocs.pm/tusk",
        source_url: "https://github.com/princemaple/tusk"
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp description do
    "Elixir task library with retry, success/failure callback and timeout"
  end

  defp package do
    [
      maintainers: ["Po Chen"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/princemaple/tusk"}
    ]
  end
end
