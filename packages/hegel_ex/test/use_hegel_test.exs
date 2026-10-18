defmodule UseHegelTest do
  use ExUnit.Case
  use Hegel

  property "use Hegel imports property and draw", database: :disabled, test_cases: 3 do
    x = draw(integer(0, 10))
    assert x in 0..10
  end
end
