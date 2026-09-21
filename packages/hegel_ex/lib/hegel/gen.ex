defmodule Hegel.Gen do
  @moduledoc "Composable generators. Values are shrunk by Hegel's native engine."
  defdelegate boolean(), to: :hegel_gen
  defdelegate boolean(probability), to: :hegel_gen
  defdelegate integer(), to: :hegel_gen
  defdelegate integer(min, max), to: :hegel_gen
  defdelegate float(), to: :hegel_gen
  defdelegate float(min, max), to: :hegel_gen
  defdelegate binary(), to: :hegel_gen
  defdelegate binary(min, max), to: :hegel_gen
  defdelegate utf8(), to: :hegel_gen
  defdelegate utf8(min, max), to: :hegel_gen
  defdelegate constant(value), to: :hegel_gen
  defdelegate one_of(generators), to: :hegel_gen
  defdelegate frequency(weighted), to: :hegel_gen
  defdelegate tuple(generators), to: :hegel_gen
  defdelegate map(fields), to: :hegel_gen
  def map(generator, fun), do: :hegel_gen.map(fun, generator)
  def bind(generator, fun), do: :hegel_gen.bind(generator, fun)
  def filter(generator, fun), do: :hegel_gen.filter(fun, generator)
  def list(generator), do: :hegel_gen.list(generator)

  def list(generator, options) do
    :hegel_gen.list(generator, Keyword.get(options, :min, 0), Keyword.get(options, :max, 16))
  end
end
