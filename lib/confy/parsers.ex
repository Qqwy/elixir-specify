defmodule Confy.Parsers do
  def integer(int) when is_integer(int), do: {:ok, int}

  def integer(binary) when is_binary(binary) do
    case Integer.parse(binary) do
      {:ok, int} -> int
      :error -> {:error, "the binary `#{binary}` cannot be parsed to an integer"}
    end
  end
  def integer(other), do: {:error, "#{inspect(other)} is not an integer"}

  def float(float) when is_float(float), do: float
  def float(int) when is_integer(int), do: 1.0 * int
  def float(binary) when is_binary(binary) do
    case Float.parse(binary) do
      {:ok, float} -> float
      :error -> {:error, "the binary `#{binary}` is not a float"}
    end
  end
  def float(other), do: {:error, "`#{inspect(other)}` is not a float"}

  def string(binary) when is_binary(binary), do: {:ok, binary}
  def string(thing) do
    try do
      {:ok, to_string(thing)}
    rescue
      ArgumentError ->
        {:error, "`#{inspect(thing)}` cannot be converted to string because it does not implement the String.Chars protocol."}
    end
  end

  def term(anything), do: {:ok, anything}

  def boolean(boolean) when is_boolean(boolean), do: {:ok, boolean}
  def boolean(binary) when is_binary(binary) do
    case binary |> Macro.underscore do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> {:error, "`#{binary}` cannot be parsed to a boolean"}
    end
  end
  def boolean(other), do: {:error, "`#{inspect(other)}` is not a boolean"}

  def atom(atom) when is_atom(atom), do: {:ok, atom}
  def atom(binary) when is_binary(binary) do
    try do
      String.to_existing_atom(binary)
    rescue
      ArgumentError ->
        {:error, "`#{binary}` is not an existing atom"}
    end
  end

  def unsafe_atom(atom) when is_atom(atom), do: {:ok, atom}
  def unsafe_atom(binary) when is_binary(binary) do
    {:ok, String.to_atom(binary)}
  end
end
