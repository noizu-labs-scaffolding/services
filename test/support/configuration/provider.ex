defmodule Noizu.Service.Support.NodeManager.ConfigurationProvider do
  @behaviour Noizu.Service.NodeManager.ConfigurationManagerBehaviour
  require Noizu.Service.NodeManager.ConfigurationManagerBehaviour
  import Noizu.Service.NodeManager.ConfigurationManagerBehaviour
  alias Noizu.Service.Support.{TestPool, TestPool2, TestPool3}

  @n1 :"first@127.0.0.1"
  @n2 :"second@127.0.0.1"
  def configuration(node) do
    case node do
      @n1 -> [TestPool, TestPool2]
      @n2 -> [TestPool2, TestPool3]
    end
    |> Enum.map(fn(service) ->
      test_pool_config = node_service(
        pool: service,
        node: node,
        priority: 0,
        supervisor_target: target_window(target: 3, low: 2, high: 4),
        worker_target: target_window(target: 6, low: 3, high: 9)
      )
      {service, test_pool_config}
    end)
    |> Map.new()
    |> then(&({:ok, &1}))
  end

  def test_service(service) do
    cluster_service(
      pool: service,
      priority: 1,
      node_target: target_window(target: 2, low: 1, high: 3),
      worker_target: target_window(target: 12, low: 6, high: 18)
    )
  end

  def configuration() do
    with {:ok, n1_services} <- configuration(@n1),
         {:ok, n2_services} <- configuration(@n2) do
      [TestPool, TestPool2, TestPool3]
      |> Enum.map(fn(service) ->
        nodes = %{}
                |> then(&(if entry = n1_services[service], do: put_in(&1, [@n1], entry), else: &1))
                |> then(&(if entry = n2_services[service], do: put_in(&1, [@n2], entry), else: &1))
        {service, %{cluster: test_service(service), nodes: nodes}}
      end)
      |> Map.new()
      |> then(&({:ok, &1}))
    end
  end


  def cached(node), do: configuration(node)
  def cached(), do: configuration()

  def cache(node, _), do: configuration(node)
  def cache(_), do: configuration()
end

