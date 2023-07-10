#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2020 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.Service.RoutingTest do
  use ExUnit.Case
  require Logger

  def context(), do: Noizu.Context.system()

  @tag :routing
  @tag :v2
  #@tag capture_log: true
  test "process across node" do
    Noizu.Service.NodeManager.bring_online(node(), context()) |> Task.yield()
    Noizu.Service.NodeManager.bring_online(:"second@127.0.0.1", context()) |> Task.yield()
    {_, host, _} = Noizu.Service.Support.TestPool.fetch(321, :process, context())
    assert host == node()
  end

  @tag :v2
  @tag capture_log: true
  test "process origin node" do
    Noizu.Service.NodeManager.bring_online(node(), context()) |> Task.yield()
    Noizu.Service.NodeManager.bring_online(:"second@127.0.0.1", context()) |> Task.yield()
    {_, host, _} = Noizu.Service.Support.TestPool3.fetch(123, :process, context())
    assert host != node()
  end

end
