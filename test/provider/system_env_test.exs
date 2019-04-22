defmodule Pet do
  require Confy
  Confy.defconfig do
    @doc "The name of the pet"
    field :name, :string
    @doc "is it a dog or a cat?"
    field :kind, :atom
  end
end

defmodule Confy.Provider.SystemEnvTest do
  use ExUnit.Case
  use ExUnitProperties


  doctest Confy.Provider.SystemEnv
end
