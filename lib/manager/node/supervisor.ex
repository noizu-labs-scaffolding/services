defmodule Noizu.Service.NodeManager.Supervisor do
  use Supervisor
  require Noizu.Service.Types
  import Noizu.Service.Types
  
  def spec(context, options \\ nil) do
    %{
      id: __MODULE__,
      type: :supervisor,
      start: {__MODULE__, :start_link, [context, options]}
    }
  end
  
  def start_link(context, options) do
    Supervisor.start_link(__MODULE__, {context, options}, name: __MODULE__)
  end
  
  def init({context, options}) do
    init_registry(context, options)
    [
      {Task.Supervisor, name: Noizu.Service.NodeManager.Task},
      Noizu.Service.NodeManager.Server.spec(context, options)]
    |> Supervisor.init(strategy: :one_for_one)
  end
  
  def add_child(spec) do
    Supervisor.start_child(__MODULE__, spec)
  end


  #===========================================
  # Registry
  #===========================================
  def init_registry(_, _) do
    status = [node: node()]
    :syn.add_node_to_scopes([__cluster_pool__(), __cluster_registry__(), __pool__(), __registry__()])
    :syn.register(__pool__(), {:supervisor, node()}, self(), status)
    :syn.join(__pool__(), :supervisors, self(), status)
  end

  #================================
  # Behaviour
  #================================
  def __pool__(), do: Noizu.Service.NodeManager
  def __server__(), do: Noizu.Service.NodeManager.Server
  def __supervisor__(), do: Noizu.Service.NodeManager.Supervisor
  def __registry__(), do: Noizu.Service.NodeManager.WorkerRegistry


  defdelegate __cluster_pool__(), to: Noizu.Service.ClusterManager, as: :__pool__
  defdelegate __cluster_server__(), to: Noizu.Service.ClusterManager, as: :__server__
  defdelegate __cluster_supervisor__(), to: Noizu.Service.ClusterManager, as: :__supervisor__
  defdelegate __cluster_registry__(), to: Noizu.Service.ClusterManager, as: :__registry__


end