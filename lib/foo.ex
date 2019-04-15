defmodule Foo do
  require Confy
  Confy.defconfig do
    @doc "The user's (first) name."
    field :name, :string, default: "Bobby"

    field :age, :integer, default: 42
  end
end
