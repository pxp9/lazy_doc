defmodule LazyDocTest do
  use ExUnit.Case
  doctest LazyDoc

  test "greets the world" do
    assert LazyDoc.hello() == :world
  end
end
