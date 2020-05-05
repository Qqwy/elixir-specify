defmodule SpecifyTest do
  use ExUnit.Case
  use ExUnitProperties
  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  doctest Specify

  describe "Simple examples of Specify.defconfig/2" do
    defmodule BasicSpecifyExample do
      require Specify

      Specify.defconfig do
        @doc "a field with a default"
        field(:name, :string, default: "Jabberwocky")
        @doc "A required field"
        field(:age, :integer)
        @doc "A compound parsers test."
        field(:colors, {:list, :atom}, default: [])
      end
    end

    test "Basic configuration works without glaring problems" do
      assert Specify.load(BasicSpecifyExample, explicit_values: [age: 42]) == %BasicSpecifyExample{
               name: "Jabberwocky",
               age: 42,
               colors: []
             }

      assert BasicSpecifyExample.load(explicit_values: [age: 43]) == %BasicSpecifyExample{
               name: "Jabberwocky",
               age: 43,
               colors: []
             }

      assert Specify.load_explicit(BasicSpecifyExample, age: 42) == %BasicSpecifyExample{
               name: "Jabberwocky",
               age: 42,
               colors: []
             }

      assert BasicSpecifyExample.load_explicit(age: 44, colors: [:red, :green]) ==
               %BasicSpecifyExample{name: "Jabberwocky", age: 44, colors: [:red, :green]}

      assert_raise(Specify.MissingRequiredFieldsError, fn ->
        Specify.load(BasicSpecifyExample)
      end)

      assert_raise(Specify.MissingRequiredFieldsError, fn ->
        Specify.load_explicit(BasicSpecifyExample, [])
      end)
    end

    test "compound parsers are used correctly" do
      assert %BasicSpecifyExample{colors: [:red, :green, :blue]} =
               BasicSpecifyExample.load_explicit(age: 22, colors: "[:red, :green, :blue]")

      assert %BasicSpecifyExample{colors: [:red, :cyan, :yellow]} =
               BasicSpecifyExample.load_explicit(age: 22, colors: [:red, "cyan", :yellow])
    end

    test "Warnings are shown when defining a configuration with missing doc strings" do
      assert capture_io(:stderr, fn ->
               defmodule MissingDocs do
                 require Specify

                 Specify.defconfig do
                   field(:name, default: "Slatibartfast")
                 end
               end
             end) =~
               "Missing documentation for configuration field `name`. Please add it by adding `@doc \"field documentation here\"` above the line where you define it."
    end

    test "Reflection is in place" do
      assert MapSet.new([:name, :age, :colors]) == BasicSpecifyExample.__specify__(:field_names)
      assert %{name: "Jabberwocky", colors: []} == BasicSpecifyExample.__specify__(:defaults)
      assert MapSet.new([:age]) == BasicSpecifyExample.__specify__(:required_fields)

      assert %{
               name: &Specify.Parsers.string/1,
               age: &Specify.Parsers.integer/1,
               colors: {&Specify.Parsers.list/2, &Specify.Parsers.atom/1}
             } == BasicSpecifyExample.__specify__(:parsers)
    end

    test "Specify shows warnings on missing (required) sources" do
      res = capture_log(fn ->
        defmodule ConfigWithRequiredSource do
          require Specify

          Specify.defconfig [sources: [Specify.Provider.SystemEnv]] do
            @doc "A name"
            field(:name, :string)
          end
        end

        conf = ConfigWithRequiredSource.load_explicit(name: "Floof")
        assert conf = %{name: "Floof"}
      end)

      assert res =~ "While loading the configuration `SpecifyTest.ConfigWithRequiredSource`, the source `%Specify.Provider.SystemEnv{optional: false, prefix: nil}` could not be found."
    end

    test "Specify does not show warnings on missing (optional) sources" do
      res = capture_log(fn ->
        defmodule ConfigWithOptionalSource do
          require Specify

          Specify.defconfig [sources: [%Specify.Provider.SystemEnv{optional: true}]] do
            @doc "A name"
            field(:name, :string)
          end
        end

        res = ConfigWithOptionalSource.load_explicit(name: "Floof")
        assert res = %{name: "Floof"}
      end)

      assert res == ""
    end
  end

  describe "parsers are properly called" do
    defmodule ParsingExample do
      require Specify

      Specify.defconfig do
        @doc false
        field(:size, :integer, default: "42")
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
          assert_raise(Specify.ParsingError, fn ->
            ParsingExample.load_explicit(size: thing)
          end)
        end
      end
    end

    property "parser failure results in (custom) error" do
      defmodule MyCustomError do
        defexception [:message]
      end

      check all thing <- term(), !is_integer(thing) do
        assert_raise(MyCustomError, fn ->
          ParsingExample.load_explicit([size: thing], parsing_error: MyCustomError)
        end)
      end
    end
  end
end
