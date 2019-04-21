defmodule Confy.ParsersTest do
  use ExUnit.Case
  use ExUnitProperties

  doctest Confy.Parsers
  alias Confy.Parsers

  describe "integer/1" do
    property "works on integers" do
      check all int <- integer() do
        assert Parsers.integer(int) === {:ok, int}
      end
    end

    property "works on binaries representing integers" do
      check all int <- integer() do
        str = to_string(int)
        assert Parsers.integer(str) === {:ok, int}
      end
    end

    property "fails on non-integer terms" do
      check all thing <- term(), !is_integer(thing) do
        assert {:error, _} = Parsers.integer(thing)
      end
    end
  end

  describe "float/1" do
    property "works on floats" do
      check all float <- float() do
        assert Parsers.float(float) === {:ok, float}
      end
    end

    property "works on integers" do
      check all int <- integer() do
        assert Parsers.float(int) === {:ok, int * 1.0}
      end
    end


    property "works on binaries representing floats" do
      check all float <- float() do
        str = to_string(float)
        assert Parsers.float(str) === {:ok, float}
      end
    end

    property "works on binaries representing integers" do
      check all int <- integer() do
        str = to_string(int)
        assert Parsers.float(str) === {:ok, 1.0 * int}
      end
    end


    property "fails on non-integer terms" do
      check all thing <- term(), !is_float(thing), !is_integer(thing) do
        assert {:error, _} = Parsers.float(thing)
      end
    end
  end

  describe "string/1" do
    property "works on binaries" do
      check all bin <- string(:printable) do
        assert {:ok, bin} = Parsers.string(bin)
      end
    end

    property "works on charlists" do
      check all bin <- string(:printable) do
        chars = to_charlist(bin)
        assert {:ok, bin} = Parsers.string(chars)
      end
    end

    property "works on ints" do
      check all int <- integer() do
        assert {:ok, "#{int}"} == Parsers.string(int)
      end
    end
  end
end
