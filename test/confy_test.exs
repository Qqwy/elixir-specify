defmodule ConfyTest do
  use ExUnit.Case
  use ExUnitProperties
  import ExUnit.CaptureIO

  doctest Confy

  describe "Simple examples of Confy.defconfig/2" do
    defmodule BasicConfyExample do
      require Confy

      Confy.defconfig do
        @doc "a name"
        field(:name, :string, default: "Jabberwocky")
        @doc "how old this BasicConfyExample is"
        field(:age, :integer)
      end
    end

    test "Basic configuration works without glaring problems" do
      assert Confy.load(BasicConfyExample, explicit_values: [age: 42]) == %BasicConfyExample{name: "Jabberwocky", age: 42}
      assert BasicConfyExample.load(explicit_values: [age: 43]) == %BasicConfyExample{name: "Jabberwocky", age: 43}

      assert Confy.load_explicit(BasicConfyExample, age: 42) == %BasicConfyExample{name: "Jabberwocky", age: 42}
      assert BasicConfyExample.load_explicit(age: 44) == %BasicConfyExample{name: "Jabberwocky", age: 44}

      assert_raise(Confy.MissingRequiredFieldsError, fn ->
        Confy.load(BasicConfyExample)
      end)

      assert_raise(Confy.MissingRequiredFieldsError, fn ->
        Confy.load_explicit(BasicConfyExample, [])
      end)
    end

    test "Warnings are shown when defining a configuration with missing doc strings" do
      assert capture_io(:stderr, fn ->
               defmodule MissingDocs do
                 require Confy

                 Confy.defconfig do
                   field(:name, default: "Slatibartfast")
                 end
               end
             end) =~
               "Missing documentation for configuration field `name`. Please add it by adding `@doc \"field documentation here\"` above the line where you define it."
    end

    test "Reflection is in place" do
      assert MapSet.new([:name, :age]) == BasicConfyExample.__confy__(:field_names)
      assert %{name: "Jabberwocky"} == BasicConfyExample.__confy__(:defaults)
      assert MapSet.new([:age]) == BasicConfyExample.__confy__(:required_fields)
      assert %{name: &Confy.Parsers.string/1, age: &Confy.Parsers.integer/1} == BasicConfyExample.__confy__(:parsers)
    end

  end

  describe "parsers are properly called" do
    defmodule ParsingExample do
      require Confy
      Confy.defconfig do
        @doc false
        field :size, :integer, default: "42"
      end
    end

    test "Parser is called with default" do
      assert ParsingExample.load() == %ParsingExample{size: 42}
    end

    property "parser is called with value" do
      check all thing <- term() do
        if is_integer(thing) do
          assert %ParsingExample{size: thing} = ParsingExample.load_explicit(size: thing)
        else
          assert_raise(Confy.ParsingError, fn () ->
            ParsingExample.load_explicit(size: thing)
          end)
        end
      end
    end

    property "parser failure results in (custom) error" do
      defmodule MyCustomError do
        defexception [:message]
      end
      check all  thing <- term(), !is_integer(thing) do
        assert_raise(MyCustomError, fn () ->
          ParsingExample.load_explicit([size: thing], [parsing_error: MyCustomError])
        end)
      end
    end
  end
end
