defmodule HegelTest do
  use ExUnit.Case
  import Hegel

  test "facade returns a structured successful run" do
    assert %{status: :passed} =
             Hegel.run(fn -> _x = draw(Hegel.Gen.integer(0, 10)) end,
               test_cases: 3,
               database: :disabled
             )
  end
end
