defmodule Confy.ParsersTest do
  use ExUnit.Case
  use ExUnitProperties

  doctest Confy.Parsers
  alias Confy.Parsers

  describe "integer/1" do
    property "integer/1 works on integers" do
      check all int <- integer() do
        assert Parsers.integer(int) == {:ok, int}
      end
    end

    property "works on binaries representing integers" do
      check all int <- integer() do
        str = to_string(int)
        assert Parsers.integer(str) == {:ok, int}
      end
    end

    property "fails on non-integer terms" do
      check all thing <- term(), !is_integer(thing) do
        assert {:error, _} = Parsers.integer(thing)
      end
    end
  end
end
