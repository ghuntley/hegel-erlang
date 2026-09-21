defmodule Hegel.Task do
  def async(fun) when is_function(fun, 0) do
    :hegel_process.spawn(:hegel.current_test_case(), fn _ -> fun.() end)
  end

  defdelegate await(task), to: :hegel_process
end
