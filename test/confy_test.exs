defmodule ConfyTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  doctest Confy

  describe "Simple examples of Confy.defconfig/2" do
    defmodule Foo do
      require Confy

      Confy.defconfig do
        @doc "a name"
        field(:name, :string, default: "Jabberwocky")
        @doc "how old this Foo is"
        field(:age, :integer)
      end
    end

    test "Basic configuration works without glaring problems" do
      assert Confy.load(Foo, explicit_values: [age: 42]) == %Foo{name: "Jabberwocky", age: 42}
      assert Foo.load(explicit_values: [age: 43]) == %Foo{name: "Jabberwocky", age: 43}

      assert Confy.load_explicit(Foo, age: 42) == %Foo{name: "Jabberwocky", age: 42}
      assert Foo.load_explicit(age: 44) == %Foo{name: "Jabberwocky", age: 44}

      assert_raise(Confy.MissingRequiredFieldsError, fn ->
        Confy.load(Foo)
      end)

      assert_raise(Confy.MissingRequiredFieldsError, fn ->
        Confy.load_explicit(Foo, [])
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
  end
end
