defmodule Hegel do
  @moduledoc """
  Property-based testing backed by Hegel's Erlang SDK.

      use Hegel

      property "reversing twice is identity" do
        xs = draw(Hegel.Gen.list(Hegel.Gen.integer()))
        assert xs |> Enum.reverse() |> Enum.reverse() == xs
      end
  """

  defmacro __using__(_options) do
    quote do
      import Hegel, only: [property: 2, property: 3, draw: 1, draw: 2]
    end
  end

  defmacro property(description, options \\ [], do: block) do
    block = name_draws(block)

    quote do
      @tag :hegel
      test unquote(description) do
        Hegel.check(fn -> unquote(block) end, unquote(options))
      end
    end
  end

  defmacro draw(generator) do
    name = Macro.to_string(generator)
    quote do: :hegel.draw(:hegel.current_test_case(), unquote(name), unquote(generator))
  end

  defmacro draw(name, generator) do
    quote do: :hegel.draw(:hegel.current_test_case(), unquote(name), unquote(generator))
  end

  def check(fun, options \\ []) when is_function(fun, 0) do
    :hegel.check(fn _test_case -> fun.() end, options(options))
  end

  def run(fun, options \\ []) when is_function(fun, 0) do
    :hegel.run(fn _test_case -> fun.() end, options(options))
  end

  def reproduce(fun, blob, options \\ []) when is_function(fun, 0) do
    :hegel.reproduce(fn _test_case -> fun.() end, blob, options(options))
  end

  def assume(value), do: :hegel.assume(value)
  def reject, do: :hegel.reject()
  def note(value), do: :hegel.note(inspect(value, pretty: true))
  def event(name, value \\ true), do: :hegel.event(name, value)
  def target(value), do: :hegel.target(value)
  def target(name, value), do: :hegel.target(name, value)
  def on_cleanup(fun), do: :hegel.on_cleanup(fun)

  defp options(options) when is_list(options), do: Map.new(options)
  defp options(options) when is_map(options), do: options

  defp name_draws(ast) do
    Macro.prewalk(ast, fn
      {:=, meta, [left, {:draw, draw_meta, [generator]}]} ->
        name = Macro.to_string(left)
        {:=, meta, [left, {:draw, draw_meta, [name, generator]}]}

      node ->
        node
    end)
  end
end
