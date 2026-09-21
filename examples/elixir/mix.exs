defmodule HegelElixirExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :hegel_elixir_example,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: [{:hegel_ex, path: "../../packages/hegel_ex"}]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
