defmodule Noizu.Service.DispatcherRouter do
  require Noizu.Service.Types
  import Noizu.Service.Types
  alias Noizu.Service.Types, as: M
  require Noizu.EntityReference.Records
  alias Noizu.EntityReference.Records, as: R


  def __lookup_worker_process__(ref = R.ref(module: worker, id: identifier)) do
    registry = apply(worker, :__registry__, [])
    with {pid, info} <- :syn.lookup(registry, {:worker, ref}) do
      {:ok, {pid, info}}
    else
      _ -> {:error, :unregistered}
    end
  end
  
  def __process__(message, _ \\ nil)
  def __process__(
        M.msg_envelope(
          recipient: ref = R.ref(module: worker, id: identifier),
          msg: msg,
          settings: settings
        ) = message,
        options
      ) do
    
    # we will need to tweak this eventually to better scale.
    # only register/ref scopes on nodes with the services (or a subset of that) and rpc.call to the node of an
    # available node manager to get the actual pid rather than syncing values across entire cluster, etc.
    
    # regardless for large scales we will likely need to tweak our registration flow here.
    registry = apply(worker, :__registry__, [])
    with {pid, _} <- :syn.lookup(registry, {:worker, ref})
                     #|> IO.inspect(label: "#{registry} check #{inspect ref}")
      do
      {:ok, pid}
    else
      :undefined ->
        cond do
          spawn?(settings) ->
            {:dispatch, __MODULE__, :waiting, start_worker(apply(worker, :__pool__, []), ref, settings, M.call_context(msg), options)}
          :else -> {:nack, :not_registered}
        end
    end
  catch e -> {:error, e}
  end
  
  def start_worker(pool, ref, settings, context, options) do
    options_b = put_in(options || [], [:return_task], true)
    Noizu.Service.ClusterManager.start_worker(pool, ref, settings, context,  options_b)
  end
  
  def __handle__(_, _), do: {:dynamic, __MODULE__, [[]]}
  
  def __register__(pool, ref, process, status) do
    registry = apply(pool, :__registry__, [])
    :syn.register(registry, {:worker, ref}, process, status)
  end

end
