# Used in multiple modules' doctests
defmodule Pet do
  require Specify
  Specify.defconfig do
    @doc "The name of the pet"
    field :name, :string
    @doc "is it a dog or a cat?"
    field :kind, :atom
  end
end

ExUnit.start()

# We require some atoms to be defined for the doctests
_some_animal_kinds = [:cat, :dog, :bird, :fish]
