defmodule Hegel.StateMachine do
  def run(initial_state, rules, options \\ []) do
    :hegel_stateful.run(:hegel.current_test_case(), initial_state, rules, Map.new(options))
  end
end
