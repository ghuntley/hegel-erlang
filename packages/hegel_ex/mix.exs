defmodule HegelEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :hegel_ex,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Idiomatic Elixir facade for the Erlang Hegel SDK",
      package: [
        licenses: ["MIT"],
        links: %{
          "Hegel" => "https://hegel.dev",
          "GitHub" => "https://github.com/ghuntley/hegel-erlang"
        }
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
  defp deps, do: [{:hegel, path: "../.."}]
end
