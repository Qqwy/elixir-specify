defmodule ConfyTest do
  use ExUnit.Case
  doctest Confy

  defmodule Foo do
    require Confy
    Confy.defconfig do
      @doc "a name"
      field :name, :string, default: "Jabberwocky"
      @doc "how old this Foo is"
      field :age, :integer
    end
  end

  test "Basic configuration works without glaring problems" do

    assert Foo.load(overrides: [age: 42]) == %Foo{name: "Jabberwocky", age: 42}
    assert_raise(Confy.MissingRequiredFieldsError, fn ->
      Foo.load()
    end)
  end
end
