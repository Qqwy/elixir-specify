defmodule ConfyTest do
  use ExUnit.Case
  doctest Confy

  test "greets the world" do
    assert Confy.hello() == :world
  end
end
