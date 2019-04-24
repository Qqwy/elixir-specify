defmodule Pet do
  require Specify
  Specify.defconfig do
    @doc "The name of the pet"
    field :name, :string
    @doc "is it a dog or a cat?"
    field :kind, :atom
  end
end

defmodule Specify.Provider.SystemEnvTest do
  use ExUnit.Case
  use ExUnitProperties


  doctest Specify.Provider.SystemEnv
end
