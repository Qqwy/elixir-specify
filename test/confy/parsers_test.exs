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

    # Yes, this property test does not work on inputs like "9".
    # I am not sure what to do about that.
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

    # Yes, this property test does not work on inputs like "9".
    # I am not sure what to do about that.
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
      check all thing <-
                  one_of([
                    integer(),
                    string(:printable),
                    binary(),
                    float(),
                    boolean(),
                    atom(:alphanumeric)
                  ]) do
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

  describe "atom/1 and unsafe_atom/1" do
    property "works on atoms" do
      check all atom <- one_of([atom(:alphanumeric), atom(:alias)]) do
        assert {:ok, atom} == Parsers.atom(atom)
        assert {:ok, atom} == Parsers.unsafe_atom(atom)
      end
    end

    property "Works on strings" do
      check all atom <- one_of([atom(:alphanumeric), atom(:alias)]) do
        str = to_string(atom)
        assert {:ok, atom} == Parsers.atom(str)
        assert {:ok, atom} == Parsers.unsafe_atom(str)
      end
    end

    test "atom/1 raises on non-existent atom" do
      assert {:error, _} = Parsers.atom("this_does_not_exist_as_atom")
      assert {:error, _} = Parsers.atom("This.Module.Does.Not.Exist.Either")
    end

    test "unsafe_atom/1 does noton non-existent atom" do
      assert {:ok, :this_does_not_exist_as_atom2} =
               Parsers.unsafe_atom("this_does_not_exist_as_atom2")

      assert {:ok, This.Module.Does.Not.Exist.Either2} =
               Parsers.unsafe_atom("Elixir.This.Module.Does.Not.Exist.Either2")
    end
  end

  describe "list/2" do
    property "works on lists" do
      check all list <- list_of(atom(:alphanumeric)) do
        assert {:ok, list} == Parsers.list(list, &Parsers.atom/1)
      end
    end
  end
end
