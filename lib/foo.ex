defmodule Foo do
  require Confy
  Confy.defconfig sources: [Confy.Provider.Process.new()] do
    @doc "The user's (first) name."
    field :name, :string, default: "Bobby"

    field :age, :integer
  end
end
