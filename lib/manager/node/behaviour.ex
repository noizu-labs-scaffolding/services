defmodule Noizu.Service.NodeManager.Configuration do

end

defmodule Noizu.Service.NodeManager.ConfigurationManagerBehaviour do
  @callback configuration(node) :: {:ok, term}
  @callback configuration() :: {:ok, term}

  @callback cached(node) :: {:ok, term}
  @callback cached() :: {:ok, term}

  @callback cache(node, term) :: {:ok, term}
  @callback cache(term) :: {:ok, term}

  require Record
  Record.defrecord(:target_window, target: nil, low: nil, high: nil)
  Record.defrecord(:node_service, state: :online, priority: nil, supervisor_target: nil, worker_target: nil, pool: nil, health_target: nil, node: nil)
  Record.defrecord(:cluster_service, state: :online, priority: nil, node_target: nil, worker_target: nil,  health_target: nil, pool: nil)
end

defmodule Noizu.Service.NodeManager.ConfigurationManager do
  def cache(provider, value) do
    apply(provider, :cache, [value])
  rescue e -> {:error, e}
  catch :exit, e -> {:error, {:exit, e}}
    e -> {:error, e}
  end
  
  def cache(provider, node, value) do
    apply(provider, :cache, [node, value])
  rescue e -> {:error, e}
  catch :exit, e -> {:error, {:exit, e}}
    e -> {:error, e}
  end
  
  def cached(provider) do
    apply(provider, :cached, [])
  rescue e -> {:error, e}
  catch :exit, e -> {:error, {:exit, e}}
    e -> {:error, e}
  end
  
  def cached(provider, node) do
    apply(provider, :cached, [node])
  rescue e -> {:error, e}
  catch :exit, e -> {:error, {:exit, e}}
    e -> {:error, e}
  end
  
  
  def configuration(provider) do
    apply(provider, :configuration, [])
  rescue e -> {:error, e}
  catch :exit, e -> {:error, {:exit, e}}
    e -> {:error, e}
  end
  
  def configuration(provider, node) do
    apply(provider, :configuration, [node])
  rescue e -> {:error, e}
  catch :exit, e -> {:error, {:exit, e}}
    e -> {:error, e}
  end
end
