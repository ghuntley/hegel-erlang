defmodule Hegel.TaskTest do
  use ExUnit.Case
  import Hegel

  test "Hegel.Task.async workers can draw" do
    assert %{status: :passed} =
             Hegel.run(
               fn ->
                 task = Hegel.Task.async(fn -> draw(Hegel.Gen.integer(0, 10)) end)
                 assert Hegel.Task.await(task) in 0..10
               end,
               test_cases: 3,
               database: :disabled
             )
  end
end
