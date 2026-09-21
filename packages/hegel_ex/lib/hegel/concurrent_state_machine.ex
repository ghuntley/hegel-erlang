defmodule Hegel.ConcurrentStateMachine do
  @moduledoc """
  Exercises rules concurrently against shared external state.

  Rules are maps with `:generate`, `:run`, and an optional `:name`. The run
  callback receives the worker's explicit Hegel test case and the command.
  """

  def run(rules, options \\ []) do
    :hegel_concurrent_stateful.run(:hegel.current_test_case(), rules, Map.new(options))
  end
end
