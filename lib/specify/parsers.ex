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
  Similar to integer/1, but only accepts integers larger than 0.
  """
  def positive_integer(val) do
    with {:ok, int} <- integer(val) do
      if int > 0 do
        {:ok, int}
      else
        {:error, "integer #{int} is not a positive integer."}
      end
    end
  end

  @doc """
  Similar to integer/1, but only accepts integers larger than or equal to 0.
  """
  def nonnegative_integer(val) do
    with {:ok, int} <- integer(val) do
      if int >= 0 do
        {:ok, int}
      else
        {:error, "integer #{int} is not a nonnegative integer."}
      end
    end
  end

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
  Similar to float/1, but only accepts floats larger than 0.
  """
  def positive_float(val) do
    with {:ok, float} <- float(val) do
      if float > 0 do
        {:ok, float}
      else
        {:error, "float #{float} is not a positive float."}
      end
    end
  end

  @doc """
  Similar to float/1, but only accepts floats larger than or equal to 0.
  """
  def nonnegative_float(val) do
    with {:ok, float} <- float(val) do
      if float >= 0 do
        {:ok, float}
      else
        {:error, "float #{float} is not a nonnegative float."}
      end
    end
  end

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

  def list(term, _) do
    {:error, "`#{inspect(term)}` does not represent an Elixir list."}
  end

  @doc """
  Allows to pass in a 'timeout' which is a common setting for OTP-related features,
  accepting either a positive integer, or the atom `:infinity`.
  """
  def timeout(raw) do
    case positive_integer(raw) do
      {:ok, int} ->
        {:ok, int}
      {:error, _} ->
        case atom(raw) do
          {:ok, :infinity} ->
            {:ok, :infinity}

          {:ok, _} ->
            {:error,
             "#{inspect(raw)} is neither a positive integer nor the special atom value `:infinity`"}

          {:error, _} ->
            {:error,
             "`#{inspect(raw)}` is neither a positive integer nor the special atom value `:infinity`"}
        end
    end
  end

  @doc """
  Parses a Module-Function-Arity tuple.

  Accepts it both as Elixir three-element tuple (where the first two elements are atoms, and the third is a nonnegative integer), or as string representation of the same.

  Will also check and ensure that this function is actually defined.
  """
  def mfa(raw) when is_binary(raw) do
    case Code.string_to_quoted(raw) do
      {:ok, {:{}, _meta, [qmodule, qfunction, arity]}} ->
        with {:ok, module} <- unquote_atom(qmodule),
             {:ok, function} <- unquote_atom(qfunction) do
          mfa({module, function, arity})
        end
      {:ok, _other} ->
        {:error, "`#{inspect(raw)}`, while parseable as Elixir code, does not represent a Module-Function-Arity tuple."}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def mfa(mfa = {module, function, arity}) when is_atom(module) and is_atom(function) and is_integer(arity) and arity >= 0 do
    if function_exported?(module, function, arity) do
      {:ok, mfa}
    else
      {:error, "function #{module}.#{function}/#{arity} does not exist."}
    end
  end

  def mfa(other_val) do
    {:error, "`#{inspect(other_val)}` is not a Module-Function-Arity tuple"}
  end

  def unquote_atom(atom) when is_atom(atom) do
    {:ok, atom}
  end

  def unquote_atom(aliased_atom = {:__aliases__, _, [atom]}) when is_atom(atom) do
      case Code.eval_quoted(aliased_atom) do
        {result, []} ->
          {:ok, result}
        other ->
          {:error, "`#{inspect(other)}` cannot be unquoted as an atom."}
      end
  end

  def unquote_atom(other) do
    {:error, "`#{inspect(other)}` cannot be unquoted as an atom."}
  end

  @doc """
  Parses a function.

  This can be a function capture, or a MFA (Module-Function-Arity) tuple, which will
  be transformed into the `&Module.function/arity` capture.

  (So in either case, you end up with a function value
  that you can call using the dot operator, i.e. `.()` or `.(maybe, some, args)`).

  ## String Contexts

  For contexts in which values are specified as strings, the parser only supports the MFA format.
  This is for security (and ease of parsing) reasons.
  """
  def function(raw) when is_binary(raw) or is_tuple(raw) do
    with {:ok, {module, function, arity}} <- mfa(raw),
      {fun, []} <- Code.eval_quoted(quote do &unquote(module).unquote(function)/unquote(arity) end) do
      {:ok, fun}
    end
  end

  def function(fun) when is_function(fun) do
    {:ok, fun}
  end

  def function(other) do
    {:error, "`#{other}` cannot be parsed as a function."}
  end
end
