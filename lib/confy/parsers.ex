defmodule Confy.Parsers do
  @moduledoc """
  Simple functions to parse strings to datatypes commonly used during configuration.

  These functions can be used as parser/validator function in a call to `Confy.Schema.field`,
  by using their shorthand name (`:integer` as shorthand for `&Confy.Parsers.integer/1`).

  (Of course, using their longhand name works as well.)


  ## Defining your own parser function

  A parser function receives the to-be-parsed/validated value as input,
  and should return `{:ok, parsed_val}` on success,
  or `{:error, reason}` on failure.

  Be aware that depending on where the configuration is loaded from,
  the to-be-parsed value might be a binary string,
  or already the Elixir type you want to convert it to.

  """

  def integer(int) when is_integer(int), do: {:ok, int}

  def integer(binary) when is_binary(binary) do
    case Integer.parse(binary) do
      {int, ""} -> {:ok, int}
      :error -> {:error, "the binary `#{binary}` cannot be parsed to an integer."}
    end
  end

  def integer(other), do: {:error, "#{inspect(other)} is not an integer."}

  def float(float) when is_float(float), do: {:ok, float}
  def float(int) when is_integer(int), do: {:ok, 1.0 * int}

  def float(binary) when is_binary(binary) do
    case Float.parse(binary) do
      {float, ""} -> {:ok, float}
      :error -> {:error, "the binary `#{binary}` is not a float."}
    end
  end

  def float(other), do: {:error, "`#{inspect(other)}` is not a float"}

  def string(binary) when is_binary(binary), do: {:ok, binary}

  def string(thing) do
    try do
      {:ok, to_string(thing)}
    rescue
      ArgumentError ->
        {:error,
         "`#{inspect(thing)}` cannot be converted to string because it does not implement the String.Chars protocol."}
    end
  end

  def term(anything), do: {:ok, anything}

  def boolean(boolean) when is_boolean(boolean), do: {:ok, boolean}

  def boolean(binary) when is_binary(binary) do
    case binary |> Macro.underscore() do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> {:error, "`#{binary}` cannot be parsed to a boolean."}
    end
  end

  def boolean(other), do: {:error, "`#{inspect(other)}` is not a boolean."}

  def atom(atom) when is_atom(atom), do: {:ok, atom}

  def atom(binary) when is_binary(binary) do
    try do
      {:ok, String.to_existing_atom(binary)}
    rescue
      ArgumentError ->
        {:error, "`#{binary}` is not an existing atom."}
    end
  end

  def atom(other), do: {:error, "`#{inspect(other)}` is not an (existing) atom."}

  def unsafe_atom(atom) when is_atom(atom), do: {:ok, atom}

  def unsafe_atom(binary) when is_binary(binary) do
    {:ok, String.to_atom(binary)}
  end

  def unsafe_atom(other), do: {:error, "`#{inspect(other)}` is not convertible to an atom."}

  @doc """
  Parses a list of elements
  """
  def list(list, elem_fun) when is_list(list) do
    res_list = Enum.reduce_while(list, [], fn
      elem, acc ->
        case elem_fun.(elem) do
          {:ok, res} -> {:cont, [res | acc]}
          {:error, reason} ->
            {:halt, {:error, "One of the elements of input list `#{inspect(list)}` failed to parse: \n#{reason}."}}
        end
    end)
    case res_list do
      {:error, reason} ->
        {:error, reason}
      parsed_list when is_list(parsed_list) ->
        {:ok, Enum.reverse(parsed_list)}
    end
  end

  def list(binary, elem_fun) when is_binary(binary) do
    case Code.string_to_quoted(binary, existing_atoms_only: true) do
      {:ok, list_ast} when is_list(list_ast) ->
        list_ast
        |> Enum.map(&Macro.expand(&1, __ENV__))
        |> list(elem_fun)
      {:ok, _not_a_list} ->
        {:error, "`#{inspect(binary)}`, while parseable as Elixir code, does not represent an Elixir list."}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
