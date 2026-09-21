defmodule Hegel.Pool do
  defdelegate new(), to: :hegel_pool
  defdelegate put(pool, value), to: :hegel_pool
  defdelegate member(pool, value), to: :hegel_pool
  defdelegate delete(pool, value), to: :hegel_pool
  defdelegate values(pool), to: :hegel_pool
  def draw(pool), do: :hegel_pool.draw(:hegel.current_test_case(), pool)
end
