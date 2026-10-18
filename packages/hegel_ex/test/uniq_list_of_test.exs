defmodule Hegel.UniqListOfTest do
  use ExUnit.Case
  import Hegel

  test "uniq_list_of respects :min" do
    assert %{status: :passed} =
             Hegel.run(
               fn ->
                 values = draw(Hegel.Gen.uniq_list_of(Hegel.Gen.integer(0, 3), min: 3, max: 5))
                 assert length(values) in 3..4
                 assert values == Enum.uniq(values)
               end,
               test_cases: 100,
               database: :disabled,
               seed: 1
             )
  end

  test "uniq_list_of rejects cases when the generator has fewer than :min values" do
    parent = self()

    result =
      Hegel.run(
        fn ->
          _ = draw(Hegel.Gen.uniq_list_of(Hegel.Gen.integer(0, 1), min: 3))
          send(parent, :returned)
        end,
        test_cases: 10,
        database: :disabled,
        seed: 1
      )

    refute_received :returned
    assert %{status: :error} = result
  end
end
