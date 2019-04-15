defmodule Foo do
  require Confy
  Confy.defconfig do
    @doc "The user's (first) name."
    field :name, :string, default: "Bobby"

    field :age, &Integer.parse/1, default: 42
  end
end
