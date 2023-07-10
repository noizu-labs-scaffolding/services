defmodule Noizu.Service.Types.Dispatch do
  require Noizu.Service.Types
  alias Noizu.Service.Types, as: M
  require Noizu.EntityReference.Records
  alias Noizu.EntityReference.Records, as: R

  def s_call(ref, handler, args, context, options \\ nil,timeout \\ :default) do
      with {:ok, pool} <- recipient_pool(ref) do
        identifier = {self(), :os.system_time(:millisecond)}
        settings = apply(pool, :__call_settings__, [])
        timeout = cond do
                    timeout == :default -> M.settings(settings, :timeout)
                    :else -> timeout
                  end
        M.msg_envelope(
          identifier: identifier,
          type: :call,
          settings: M.settings(settings, spawn?: false, timeout: timeout),
          recipient: ref,
          msg: M.s(call: M.call(handler: handler, args: args), context: context, options: options)
        ) |> __dispatch__()
      end
  end

  def s_call!(ref, handler, args, context, options \\ nil, timeout \\ :default) do
    with {:ok, pool} <- recipient_pool(ref) do
      identifier = {self(), :os.system_time(:millisecond)}
      settings = apply(pool, :__call_settings__, [])
      timeout = cond do
                  timeout == :default -> M.settings(settings, :timeout)
                  :else -> timeout
                end
      M.msg_envelope(
        identifier: identifier,
        type: :call,
        settings: M.settings(settings, spawn?: true, timeout: timeout),
        recipient: ref,
        msg: M.s(call:  M.call(handler: handler, args: args), context: context, options: options)
      ) |> __dispatch__()
    end
  end

  def s_cast(ref, handler, args, context, options \\ nil, timeout \\ :default) do
    with {:ok, pool} <- recipient_pool(ref) do
      identifier = {self(), :os.system_time(:millisecond)}
      settings = apply(pool, :__cast_settings__, [])
      timeout = cond do
                  timeout == :default -> M.settings(settings, :timeout)
                  :else -> timeout
                end
      M.msg_envelope(
        identifier: identifier,
        type: :cast,
        settings: M.settings(settings, spawn?: false, timeout: timeout),
        recipient: ref,
        msg: M.s(call:  M.call(handler: handler, args: args), context: context, options: options)
      ) |> __dispatch__()
    end
  end


  def s_cast!(ref, handler, args, context, options \\ nil, timeout \\ :default) do
    with {:ok, pool} <- recipient_pool(ref) do
      identifier = {self(), :os.system_time(:millisecond)}
      settings = apply(pool, :__cast_settings__, [])
      timeout = cond do
                  timeout == :default -> M.settings(settings, :timeout)
                  :else -> timeout
                end
      M.msg_envelope(
        identifier: identifier,
        type: :cast,
        settings: M.settings(settings, spawn?: true, timeout: timeout),
        recipient: ref,
        msg: M.s(call:  M.call(handler: handler, args: args), context: context, options: options)
      ) |> __dispatch__()
    end
  end
  
  
  def __dispatch__(M.msg_envelope(identifier: identifier, settings: settings) = message) do
    case as_task(settings) do
      false -> __dispatch__inner(message)
      nil -> __dispatch__inner(message)
      true -> Task.async(__MODULE__, :__dispatch__inner, [message])
      task_supervisor ->
        Task.Supervisor.async_nolink(task_supervisor, __MODULE__, :__dispatch__inner, [message])
    end
  end
  
  def __dispatch__inner(M.msg_envelope(settings: settings) = message) do
    cond do
      safe_call(settings) ->
        try do
          __dispatch__inner__do(message)
        rescue e -> {:error, e}
        catch
          :exit, e -> {:error, {:exit, e}}
          e -> {:error, e}
        end
      :else ->
        __dispatch__inner__do(message)
    end
  end

  def __dispatch__inner__do(M.msg_envelope(type: :cast, recipient: recipient, settings: settings) = message) do
    case recipient_register(recipient) do
      {:dynamic, dispatcher, terms} ->
        apply(dispatcher, :__process__, [message| (terms || [])])
      {:ok, handle} -> {:ok, handle}
      M.link(process: pid) -> {:ok, pid}
      error -> error
    end
    |> case do
         {:dispatch, dispatcher, :waiting, task} ->
           with {:ok, {:ok, handle}} <- Task.yield(task, timeout(settings)) do
             GenServer.cast(handle, message)
           end
         {:ok, handle} -> GenServer.cast(handle, message)
         error -> error
       end
  end

  def __dispatch__inner__do(M.msg_envelope(type: :call, recipient: recipient, settings: settings) = message) do
    case recipient_register(recipient) do
      {:dynamic, dispatcher, terms} ->
        apply(dispatcher, :__process__, [message| (terms || [])])
      {:ok, handle} -> {:ok, handle}
      M.link(process: pid) -> {:ok, pid}
      error -> error
    end
    |> case do
         {:dispatch, dispatcher, :waiting, task} ->
           with {:ok, {:ok, handle}} <- Task.yield(task, timeout(settings)) do
             GenServer.call(handle, message, timeout(settings))
           end
         {:ok, handle} -> GenServer.call(handle, message, timeout(settings))
         error -> error
       end
  end


  def safe_call(nil), do: false
  def safe_call(M.settings(safe: v)), do: v
  
  
  def as_task(nil), do: 5_000
  def as_task(M.settings(task: v)), do: v
  
  def timeout(nil), do: 5_000
  def timeout(M.settings(timeout: v)), do: v
  
  
  
  def recipient_ref(recipient)
  def recipient_ref(R.ref(module: worker) = recipient), do: {:ok, recipient}
  def recipient_ref(R.ref(module: worker) = recipient), do: {:ok, recipient}
  def recipient_ref(M.link(recipient: recipient)) do
    recipient_ref(recipient)
  end
  def recipient_ref(recipient) do
    {:error, {:unsupported, recipient}}
  end
  
  
  def recipient_register(recipient, hint \\ nil)
  def recipient_register(R.ref(module: worker) = recipient, hint) do
    worker
    |> apply(:__dispatcher__, [])
    |> apply(:__handle__, [recipient, hint])
  end
  def recipient_register(M.link(node: nil, process: nil, recipient: recipient), hint) do
    recipient_register(recipient, hint)
  end
  def recipient_register(M.link(node: node, process: nil, recipient: recipient), hint) do
    recipient_register(recipient, hint || node)
  end
  def recipient_register(M.link() = link, _) do
    link
  end
  def recipient_register(M.server(recipient: recipient) = r, hint) do
    with {:ok, pool} <- recipient_pool(recipient) do
      pool
      |> apply(:__server__, [])
      |> apply(:__dispatcher__, [])
      |> apply(:__handle__, [r, hint])
    end
  end
  def recipient_register(M.monitor(recipient: recipient) = r, hint) do
    with {:ok, pool} <- recipient_pool(recipient) do
      pool
      |> apply(:__monitor__, [])
      |> apply(:__dispatcher__, [])
      |> apply(:__handle__, [r, hint])
    end
  end
  def recipient_register(M.worker_supervisor(recipient: recipient) = r, hint) do
    with {:ok, pool} <- recipient_pool(recipient) do
      pool
      |> apply(:__worker_supervisor__, [])
      |> apply(:__dispatcher__, [])
      |> apply(:__handle__, [r, hint])
    end
  end
  def recipient_register(M.node_manager(recipient: recipient), hint) do
    Noizu.Service.NodeManager
    |> apply(:__dispatcher__, [])
    |> apply(:__handle__, [recipient, hint])
  end

  def recipient_pool(M.link(recipient: inner)) do
    recipient_pool(inner)
  end
  def recipient_pool(R.ref(module: m)) do
    {:ok, apply(m, :__pool__, [])}
  end
  def recipient_pool(M.pool(recipient: recipient)) do
    with {:ok, pool} <- recipient_pool(recipient) do
      {:ok, pool}
    end
  end
  def recipient_pool(M.server(recipient: recipient)) do
    with {:ok, pool} <- recipient_pool(recipient) do
      {:ok, pool}
    end
  end
  def recipient_pool(M.monitor(recipient: recipient)) do
    with {:ok, pool} <- recipient_pool(recipient) do
      {:ok, pool}
    end
  end
  def recipient_pool(M.worker_supervisor(recipient: recipient)) do
    with {:ok, pool} <- recipient_pool(recipient) do
      {:ok, pool}
    end
  end
  def recipient_pool(M.node_manager(recipient: recipient)) do
    {:ok, Noizu.Service.NodeManager}
  end
end
