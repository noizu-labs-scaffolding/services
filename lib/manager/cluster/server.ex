defmodule Noizu.Service.ClusterManager.Server do
  use GenServer
  require Record
  require Noizu.Service.Types
  import Noizu.Service.Types
  
  alias Noizu.Service.Types.Handle, as: MessageHandler
  
  #===========================================
  # Struct
  #===========================================
  @pool Noizu.Service.ClusterManager
  defstruct [
    health_report: :pending_cluster_report,
    cluster_config: [],
    meta: []
  ]
  
  Record.defrecord(:cluster_status, node: nil, status: nil, manager_state: nil, health_index: 0.0, started_on: nil, updated_on: nil)


  #===========================================
  # Config
  #===========================================
  def __configuration_provider__(), do: Noizu.Service.ClusterManager.__configuration_provider__()
  
  #===========================================
  # Server
  #===========================================
  def start_link(context, options) do
    GenServer.start_link(__MODULE__, {context, options}, name: __MODULE__)
  end

  
  def init({context, options}) do
    configuration = (with {:ok, configuration} <-
                            __configuration_provider__()
                            |> Noizu.Service.NodeManager.ConfigurationManager.configuration() do
                       configuration
                     else
                       e = {:error, _} -> e
                       error -> {:error, {:invalid_response, error}}
                     end)
    init_registry(context, options)
    {:ok, %Noizu.Service.ClusterManager.Server{cluster_config: configuration}}
  end
  
  def spec(context, options \\ nil) do
    %{
      id: __MODULE__,
      type: :worker,
      start: {__MODULE__, :start_link, [context, options]}
    }
  end
  
  #===========================================
  # Registry
  #===========================================
  def init_registry(_, _) do
    ts = :os.system_time(:second)
    status = cluster_status(node: node(), status: :initilizing, manager_state: :init, health_index: 0.0, started_on: ts, updated_on: ts)
    refresh_registry(self(), status)
  end

  def refresh_registry(pid, status) do
    :syn.register(__pool__(), :manager, pid, status)
    apply(__dispatcher__(), :__register__, [__pool__(), {:ref, __MODULE__, :manager}, pid, status])
  end
  
  #================================
  # Routing
  #================================
  
  #-----------------------
  #
  #-----------------------
  def handle_call(msg_envelope() = call, from, state) do
    MessageHandler.unpack_call(call, from, state)
  end
  def handle_call(s(call: :health_report, context: context), _, state) do
    health_report(state, context)
  end
  def handle_call(s(call: :configuration, context: context), _, state) do
    configuration(state, context)
  end
  def handle_call(call, from, state), do: MessageHandler.uncaught_call(call, from, state)
  
  #-----------------------
  #
  #-----------------------
  def handle_cast(msg_envelope() = call, state) do
    MessageHandler.unpack_cast(call, state)
  end
  def handle_cast(call, state), do: MessageHandler.uncaught_cast(call, state)
  
  #-----------------------
  #
  #-----------------------
  def handle_info(msg_envelope() = call, state) do
    MessageHandler.unpack_info(call, state)
  end
  def handle_info(call, state), do: MessageHandler.uncaught_info(call, state)


  #================================
  # Behaviour
  #================================
  def __pool__(), do: Noizu.Service.ClusterManager
  def __server__(), do: Noizu.Service.ClusterManager.Server
  def __supervisor__(), do: Noizu.Service.ClusterManager.Supervisor
  def __dispatcher__(), do: apply(__pool__(), :__dispatcher__, [])
  def __registry__(), do: apply(__pool__(), :__registry__, [])
  #================================
  # Methods
  #================================
  def health_report(state, _context) do
    {:reply, state.health_report, state}
  end

  def configuration(state, _context) do
    {:reply, state.cluster_config, state}
  end
  
end
