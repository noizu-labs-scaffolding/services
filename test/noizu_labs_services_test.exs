defmodule NoizuLabsServicesTest do
  use ExUnit.Case
  doctest NoizuLabsServices

  test "greets the world" do
    assert NoizuLabsServices.hello() == :world
  end
end
