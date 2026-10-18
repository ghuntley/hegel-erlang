defmodule Hegel.Gen do
  @moduledoc "Composable generators. Values are shrunk by Hegel's native engine."
  @type t :: term()
  defdelegate boolean(), to: :hegel_gen
  defdelegate boolean(probability), to: :hegel_gen
  defdelegate integer(), to: :hegel_gen
  defdelegate integer(min, max), to: :hegel_gen
  def positive_integer(), do: integer(1, 1_000_000)
  def non_negative_integer(), do: integer(0, 1_000_000)
  def integer(%Range{first: first, last: last}), do: integer(first, last)
  defdelegate float(), to: :hegel_gen
  defdelegate float(min, max), to: :hegel_gen
  defdelegate binary(), to: :hegel_gen
  defdelegate binary(min, max), to: :hegel_gen
  def binary(options) when is_list(options) do
    case Keyword.get(options, :length) do
      nil -> binary(Keyword.get(options, :min_length, 0), Keyword.get(options, :max_length, 256))
      length -> binary(length, length)
    end
  end
  @spec term() :: term()
  def term do
    one_of([integer(), boolean(), binary(), utf8()])
  end

  defdelegate utf8(), to: :hegel_gen
  defdelegate utf8(min, max), to: :hegel_gen
  defdelegate constant(value), to: :hegel_gen
  defdelegate one_of(generators), to: :hegel_gen
  defdelegate frequency(weighted), to: :hegel_gen
  def tuple(generators) when is_tuple(generators), do: tuple(Tuple.to_list(generators))
  def tuple(generators), do: :hegel_gen.tuple(generators)
  defdelegate map(fields), to: :hegel_gen
  @spec member_of([term()]) :: term()
  def member_of(values) when is_list(values), do: one_of(Enum.map(values, &constant/1))
  @spec list_of(term(), keyword()) :: term()
  def list_of(generator, options \\ []), do: list(generator, options)
  @spec uniq_list_of(term(), keyword()) :: term()
  def uniq_list_of(generator, options \\ []) do
    min = Keyword.get(options, :min, 0)
    max = Keyword.get(options, :max, 16)

    generator =
      if is_tuple(generator) and elem(generator, 0) != :gen,
        do: tuple(Tuple.to_list(generator)),
        else: generator

    bind(integer(min..max), fn target ->
      :hegel_gen.custom(
        fn test_case -> draw_uniq(generator, test_case, target, min, MapSet.new(), [], 0) end,
        fn format, args -> :io_lib.format(format, args) end
      )
    end)
  end

  # Give up after this many duplicate draws in a row.
  @uniq_max_tries 10

  defp draw_uniq(generator, test_case, target, min, seen, acc, tries) do
    count = MapSet.size(seen)

    cond do
      count == target ->
        Enum.reverse(acc)

      tries == @uniq_max_tries ->
        # Too few distinct values for `min`: reject the case instead of returning a short list.
        if count < min, do: :hegel.reject()
        Enum.reverse(acc)

      true ->
        value = :hegel_gen.run(generator, test_case)

        if MapSet.member?(seen, value) do
          draw_uniq(generator, test_case, target, min, seen, acc, tries + 1)
        else
          draw_uniq(generator, test_case, target, min, MapSet.put(seen, value), [value | acc], 0)
        end
    end
  end

  @spec optional(term(), keyword()) :: term()
  def optional(generator, options \\ []) do
    probability = Keyword.get(options, :probability, 0.5)
    frequency([{probability, constant(nil)}, {1.0 - probability, generator}])
  end

  @spec string(keyword()) :: term()
  def string(options \\ []) do
    options = if is_atom(options), do: [kind: options], else: options
    min = Keyword.get(options, :length, Keyword.get(options, :min_length, Keyword.get(options, :min, 0)))
    max = Keyword.get(options, :length, Keyword.get(options, :max_length, Keyword.get(options, :max, 64)))
    char =
      case Keyword.get(options, :kind) do
        values when is_list(values) -> member_of(values)
        :alphanumeric -> one_of([integer(48..57), integer(65..90), integer(97..122)])
        :utf8 -> integer(0..127)
        _ -> integer(32..126)
      end

    map(list(char, min: min, max: max), &List.to_string/1)
  end

  def string(kind, options), do: string(Keyword.put(options, :kind, kind))

  @spec map_of(term(), term(), keyword()) :: term()
  def map_of(key, value, options \\ []) do
    map(list_of(tuple([key, value]), options), &Map.new/1)
  end

  def map(generator, fun), do: :hegel_gen.map(fun, generator)
  def bind(generator, fun), do: :hegel_gen.bind(generator, fun)
  def filter(generator, fun), do: :hegel_gen.filter(fun, generator)
  def list(generator) do
    generator =
      if is_tuple(generator) and elem(generator, 0) != :gen,
        do: tuple(Tuple.to_list(generator)),
        else: generator

    :hegel_gen.list(generator)
  end

  def list(generator, options) do
    generator =
      if is_tuple(generator) and elem(generator, 0) != :gen,
        do: tuple(Tuple.to_list(generator)),
        else: generator
    exact = Keyword.get(options, :length)
    min = Keyword.get(options, :min, Keyword.get(options, :min_length, exact || 0))
    max = Keyword.get(options, :max, Keyword.get(options, :max_length, exact || 16))
    :hegel_gen.list(generator, min, max)
  end

  def resize(generator, max) when is_integer(max) and max >= 0,
    do: list(generator, min: 0, max: max)

  def shuffle(values) when is_list(values), do: constant(Enum.shuffle(values))
  def shuffle(generator), do: map(list(generator), &Enum.shuffle/1)
end
