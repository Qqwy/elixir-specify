defmodule Confy.Parsers do
  def integer(int) when is_integer(int), do: {:ok, int}

  def integer(binary) when is_binary(binary) do
    case Integer.parse(binary) do
      {:ok, int} -> int
      :error -> {:error, "#`{binary}` is not an integer"}
    end
  end

  def float(float) when is_float(float), do: float
  def float(int) when is_integer(int), do: 1.0 * int
  def float(binary) when is_binary(binary) do
    case Float.parse(binary) do
      {:ok, float} -> float
      :error -> {:error, "`#{binary}` is not a float"}
    end
  end

  def string(binary) when is_binary(binary), do: binary
  def string(thing) do
    try do
      {:ok, to_string(thing)}
    rescue
      ArgumentError ->
        {:error, "`#{inspect(thing)}` cannot be converted to string because it does not implement the String.Chars protocol."}
    end
  end

  def term(anything), do: {:ok, anything}
end
