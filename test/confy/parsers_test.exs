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
      check all thing <- term() do
        if is_integer(thing) do
          assert {:ok, thing} = Parsers.integer(thing)
        else
          assert {:error, _} = Parsers.integer(thing)
        end
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
      check all thing <- term() do
        if(is_float(thing) or is_integer(thing)) do
          assert {:ok, 1.0 * thing} == Parsers.float(thing)
        else
          assert {:error, _} = Parsers.float(thing)
        end
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

    property "works on terms that implement String.Chars" do
      check all thing <- one_of([integer(), string(:printable), binary(), float(), boolean(), atom(:alphanumeric)]) do
        assert {:ok, "#{thing}"} == Parsers.string(thing)
      end
    end
  end

  describe "boolean/1" do
    property "works on booleans" do
      check all bool <- boolean() do
        assert {:ok, bool} == Parsers.boolean(bool)
      end
    end

    property "works on strings representing booleans" do
      check all bool <- boolean() do
        str = to_string(bool)
        assert {:ok, bool} == Parsers.boolean(str)
      end
    end

    property "does not work on non-boolean terms" do
      check all thing <- term() do
        if is_boolean(thing) do
          assert {:ok, thing} == Parsers.boolean(thing)
        else
          assert {:error, _} = Parsers.boolean(thing)
        end
      end
    end
  end
end
