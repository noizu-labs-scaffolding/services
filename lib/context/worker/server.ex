defmodule Noizu.Service.Worker.Server do
  use GenServer
  require Noizu.Service.Types
  alias Noizu.Service.Types, as: M
  require Noizu.EntityReference.Records
  alias Noizu.EntityReference.Records, as: R
  require Logger
  def start_link(ref = R.ref(module: m, identifier: id), args, context) do
    #IO.puts "STARTING: #{inspect m}"
    pool = apply(m, :__pool__, [])
    mod = pool.config()[:otp][:worker_server] || __MODULE__
    GenServer.start_link(mod, {ref, args, context})
    # |> IO.inspect(label: "#{pool}.worker.server start_link")
  end

  def terminate(reason, %{identifier: R.ref(module: worker, identifier: id)} = state) do
    Logger.warning("[#{worker}.start] #{inspect id}")
    super(reason, state)
  end
  def terminate(reason, state) do
    super(reason, state)
  end

  def init({ref = R.ref(module: worker, identifier: id), args, context}) do
    Logger.info("[#{worker}.start] #{inspect id}")
    init_worker = apply(worker, :init, [ref, args, context])
    pool = apply(worker, :__pool__, [])
    #registry = apply(pool, :__registry__, [])
    dispatcher = apply(pool, :__dispatcher__, [])
    apply(dispatcher, :__register__, [pool, ref, self(), [node: node()]])
    # :syn.register(registry, {:worker, ref}, self(), [node: node()])

    
    state = %Noizu.Service.Worker.State{
      identifier: ref,
      handler: worker,
      status: :init,
      status_info: nil,
      worker: init_worker,
    }
    {:ok, state}
  end
  
  def spec(ref, args, context, options \\ nil) do
    gen_server = options[:server] || Noizu.Service.Worker.Server
    %{
      id: ref,
      restart: :permanent,
      type: :worker,
      start: {gen_server, :start_link, [ref, [args], context]}
    }
  end

  def handle_call(msg, from, state) do
    apply(state.handler, :handle_call, [msg, from, state])
  end
  def handle_cast(msg, state) do
    apply(state.handler, :handle_cast, [msg, state])
  end
  def handle_info(msg, state) do
    apply(state.handler, :handle_info, [msg, state])
  end
  
end
