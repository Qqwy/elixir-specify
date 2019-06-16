defmodule Specify.Parsers do
  @moduledoc """
  Simple functions to parse strings to datatypes commonly used during configuration.

  These functions can be used as parser/validator function in a call to `Specify.Schema.field`,
  by using their shorthand name (`:integer` as shorthand for `&Specify.Parsers.integer/1`).

  (Of course, using their longhand name works as well.)


  ## Defining your own parser function

  A parser function receives the to-be-parsed/validated value as input,
  and should return `{:ok, parsed_val}` on success,
  or `{:error, reason}` on failure.

  Be aware that depending on where the configuration is loaded from,
  the to-be-parsed value might be a binary string,
  or already the Elixir type you want to convert it to.

  """

  @doc """
  Parses an integer and turns binary string representing an integer into an integer.
  """
  def integer(int) when is_integer(int), do: {:ok, int}

  def integer(binary) when is_binary(binary) do
    case Integer.parse(binary) do
      {int, ""} -> {:ok, int}
      {_int, _rest} -> {:error, "the binary `#{binary}` cannot be parsed to an integer."}
      :error -> {:error, "the binary `#{binary}` cannot be parsed to an integer."}
    end
  end

  def integer(other), do: {:error, "#{inspect(other)} is not an integer."}

  @doc """
  Parses a float and turns a binary string representing a float into an float.

  Will also accept integers, which are turned into their float equivalent.
  """
  def float(float) when is_float(float), do: {:ok, float}
  def float(int) when is_integer(int), do: {:ok, 1.0 * int}

  def float(binary) when is_binary(binary) do
    case Float.parse(binary) do
      {float, ""} -> {:ok, float}
      {_float, _rest} -> {:error, "the binary `#{binary}` cannot be parserd to  a float."}
      :error -> {:error, "the binary `#{binary}` cannot be parserd to a float."}
    end
  end

  def float(other), do: {:error, "`#{inspect(other)}` is not a float"}

  @doc """
  Parses a binary string and turns anything that implements `String.Chars` into its binary string representation by calling `to_string/1` on it.
  """
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

  @doc """
  Accepts any Elixir term as-is. Will not do any parsing.

  Only use this as a last resort. It is usually better to create your own dedicated parsing function instead.
  """
  def term(anything), do: {:ok, anything}

  @doc """
  Parses a boolean or a binary string representing a boolean value, turning it into a boolean.
  """
  def boolean(boolean) when is_boolean(boolean), do: {:ok, boolean}

  def boolean(binary) when is_binary(binary) do
    case binary |> Macro.underscore() do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> {:error, "`#{binary}` cannot be parsed to a boolean."}
    end
  end

  def boolean(other), do: {:error, "`#{inspect(other)}` is not a boolean."}

  @doc """
  Parses an atom or a binary string representing an (existing) atom.

  Will not create new atoms (See `String.to_existing_atom/1` for more info).
  """
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

  @doc """
  Parses an atom or a binary string representing an (potentially not yet existing!) atom.

  Will create new atoms. Whenever possible, consider using `atom/1` instead.
  (See `String.to_atom/1` for more info on why creating new atoms is usually a bad idea).
  """
  def unsafe_atom(atom) when is_atom(atom), do: {:ok, atom}

  def unsafe_atom(binary) when is_binary(binary) do
    {:ok, String.to_atom(binary)}
  end

  def unsafe_atom(other), do: {:error, "`#{inspect(other)}` is not convertible to an atom."}

  @doc """
  Parses a list of elements.

  In the case a binary string was passed, this parser uses `Code.string_to_quoted` under the hood to check for Elixir syntax, and will only accepts binaries representing lists.

  If a list was passed in (or after turning a binary into a list), it will try to parse each of the elements in turn.
  """
  def list(list, elem_parser) when is_list(list) do
    res_list =
      Enum.reduce_while(list, [], fn
        elem, acc ->
          case elem_parser.(elem) do
            {:ok, res} ->
              {:cont, [res | acc]}

            {:error, reason} ->
              {:halt,
               {:error,
                "One of the elements of input list `#{inspect(list)}` failed to parse: \n#{reason}."}}
          end
      end)

    case res_list do
      {:error, reason} ->
        {:error, reason}

      parsed_list when is_list(parsed_list) ->
        {:ok, Enum.reverse(parsed_list)}
    end
  end

  def list(binary, elem_parser) when is_binary(binary) do
    case Code.string_to_quoted(binary, existing_atoms_only: true) do
      {:ok, list_ast} when is_list(list_ast) ->
        list_ast
        |> Enum.map(&Macro.expand(&1, __ENV__))
        |> list(elem_parser)

      {:ok, _not_a_list} ->
        {:error,
         "`#{inspect(binary)}`, while parseable as Elixir code, does not represent an Elixir list."}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
