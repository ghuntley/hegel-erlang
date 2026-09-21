defmodule HegelElixirExampleTest do
  use ExUnit.Case
  use Hegel

  property "reversing an integer list twice preserves it",
    database: :disabled,
    seed: 2026 do
    values = draw(Hegel.Gen.list(Hegel.Gen.integer()))
    assert Enum.reverse(Enum.reverse(values)) == values
  end
end
