defmodule HegelElixirExample do
  @moduledoc "A runnable introduction to Hegel's Elixir API."

  require Hegel

  def reverse_property do
    Hegel.check(
      fn ->
        values = Hegel.draw("values", Hegel.Gen.list(Hegel.Gen.integer()))

        unless Enum.reverse(Enum.reverse(values)) == values do
          raise "reversing twice changed the list"
        end
      end,
      database: :disabled,
      seed: 2026
    )
  end

  def failure_demo do
    Hegel.check(
      fn ->
        value = Hegel.draw("value", Hegel.Gen.integer(0, 100))
        true = value < 10
      end,
      database: :disabled,
      seed: 2026
    )
  end
end
