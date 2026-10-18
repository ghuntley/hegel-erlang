defmodule Hegel.GenTest do
  use ExUnit.Case
  import Hegel

  test "optional draws nil or a value from the generator" do
    assert %{status: :passed} =
             Hegel.run(
               fn ->
                 value = draw(Hegel.Gen.optional(Hegel.Gen.integer(0, 10)))
                 assert is_nil(value) or value in 0..10
               end,
               test_cases: 10,
               database: :disabled
             )
  end

  test "optional with probability 1.0 always draws nil" do
    assert %{status: :passed} =
             Hegel.run(
               fn ->
                 assert is_nil(draw(Hegel.Gen.optional(Hegel.Gen.integer(), probability: 1.0)))
               end,
               test_cases: 10,
               database: :disabled
             )
  end
end
