#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.Service.AcceptanceTest do
  use ExUnit.Case
  require Logger
  require Noizu.Service.NodeManager.ConfigurationManagerBehaviour
  require Noizu.Service.NodeManager
  import Noizu.Service.NodeManager
  import Noizu.Service.NodeManager.ConfigurationManagerBehaviour
  
  def context(), do: Noizu.Context.system()

  describe "Cluster Manager" do
    test "health_report" do
      report = Noizu.Service.ClusterManager.health_report(context())
      assert report == :pending_cluster_report
    end
    
    test "config" do
      cluster = Noizu.Service.ClusterManager.configuration(context())
      tp = cluster[Noizu.Service.Support.TestPool][:cluster]
      assert tp != nil
      assert cluster_service(tp, :state) == :online
      assert cluster_service(tp, :priority) == 1
    end

    test "status" do
      task = Noizu.Service.NodeManager.bring_online(node(), context())
      Task.yield(task, :infinity)
      {:ok, nodes} = Noizu.Service.ClusterManager.service_status(Noizu.Service.Support.TestPool, context())
      {_pid, status} = nodes[node()]
      assert (pool_status(status, :health)) == 1.0
      # pending
    end
    
  end

  describe "Node Manager" do
    test "health_report" do
      report = Noizu.Service.NodeManager.health_report(node(), context())
      assert report == :pending_node_report
      # pending
    end
  
    test "config" do
      node = Noizu.Service.NodeManager.configuration(node(), context())
      tp = node[Noizu.Service.Support.TestPool]
      assert tp != nil
      assert node_service(tp, :state) == :online
      assert node_service(tp, :priority) == 0
    end

    test "bring_online" do
      task = Noizu.Service.NodeManager.bring_online(node(), context())
      {:ok, _} = Task.yield(task, :infinity)
      # pending
    end

    test "status" do
      task = Noizu.Service.NodeManager.bring_online(node(), context())
      Task.yield(task, :infinity)
      {:ok, {_pid, status}} = Noizu.Service.NodeManager.service_status(Noizu.Service.Support.TestPool, node(), context())
      assert (pool_status(status, :health)) == :initializing
      # pending
    end
   
  end
  
  describe "Pool" do
    test "spawn workers" do
      task = Noizu.Service.NodeManager.bring_online(node(), context())
      Task.yield(task, :infinity)

      r = Noizu.Service.Support.TestPool.test(1,  context())
      assert r == 1
      Process.sleep(500)
      r = Noizu.Service.Support.TestPool.test(1,  context())
      assert r == 2
      r = Noizu.Service.Support.TestPool.test(2,  context())
      assert r == 1
      r = Noizu.Service.Support.TestPool.test(1,  context())
      assert r == 3
    end

    test "direct link" do
      task = Noizu.Service.NodeManager.bring_online(node(), context())
      Task.yield(task, :infinity)
  
      r = Noizu.Service.Support.TestPool.test(5,  context())
      assert r == 1
      r = Noizu.Service.Support.TestPool.test(5,  context())
      assert r == 2
      r = Noizu.Service.Support.TestPool.test(6,  context())
      assert r == 1

      link = Noizu.Service.Support.TestPool.get_direct_link!(5, context())
      
      r = Noizu.Service.Support.TestPool.test(link,  context())
      assert r == 3

      r = Noizu.Service.Support.TestPool.test(5,  context())
      assert r == 4
      
    end
    
    
    
  end
  
end