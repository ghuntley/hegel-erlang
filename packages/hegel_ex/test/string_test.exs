defmodule Hegel.StringTest do
  use ExUnit.Case
  import Hegel

  test "string(kind: :utf8) draws valid strings beyond ASCII" do
    parent = self()

    assert %{status: :passed} =
             Hegel.run(
               fn ->
                 string = draw(Hegel.Gen.string(kind: :utf8, min: 1, max: 20))
                 assert String.valid?(string)
                 send(parent, {:codepoints, String.to_charlist(string)})
               end,
               test_cases: 100,
               database: :disabled,
               seed: 1
             )

    assert Enum.any?(drain([]), &(&1 > 127))
  end

  defp drain(acc) do
    receive do
      {:codepoints, codepoints} -> drain(codepoints ++ acc)
    after
      0 -> acc
    end
  end
end
