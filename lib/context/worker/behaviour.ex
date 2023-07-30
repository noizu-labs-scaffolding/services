defmodule Noizu.Service.Worker.Behaviour do
  require Logger
  require Record
  require Noizu.Service.Types
  alias Noizu.Service.Types, as: M
  alias Noizu.Service.Types.Handle, as: MessageHandler
  require Noizu.EntityReference.Records
  alias Noizu.EntityReference.Records, as: R


  @entity_repo Application.compile_env(:noizu_labs_entities, :entity_repo)


  @type worker :: any
  @type info :: atom | term

  @type state :: Noizu.Service.Worker.State.t
  @type context :: term
  @type options :: term | Map.t | nil
  
  @type response_tuple :: {:ok, term} | {:error, term}
  @type response_struct(type) :: {:ok, type} | {:error, term}
  
  @type noreply_response :: {:noreply, state} | {:noreply, state, term}
  @type reply_response(response) :: {:reply, response, state} | {:reply, response, state, term}
  @type worker_identifier :: term
  @type ref :: {:ref, module, term} | worker_identifier
  
  
  @callback __pool__() :: module
  @callback __dispatcher__() :: module
  @callback __registry__() :: module

  @callback recipient(term) :: response_tuple()

  @callback init(ref, term, term) :: state()
  @callback load(state, context, options) :: response_struct(state)
  @callback reload!(state, context, options) :: reply_response(state | any)
  
  @callback fetch(state, value :: term, context, options) :: reply_response(any)
  @callback ping(state,  context, options) :: reply_response({:pong, pid})
  @callback wake!(state,  context, options) :: reply_response({:pong, pid})
  @callback kill!(state, context, options) :: noreply_response()
  @callback crash!(state, context, options) :: noreply_response()
  @callback hibernate(state, context, options) :: noreply_response()
  @callback persist!(state, context, options) :: reply_response({:ok, state} | {:ok, term} | {:error, term})

  #-----------------------
  #
  #-----------------------
  def handle_call(_, M.msg_envelope() = call, from, state) do
    MessageHandler.unpack_call(call, from, state)
  end
  def handle_call(m, M.s(call: M.call(handler: h, args: args), context: context, options: options), _, state) do
    o = apply(m, h, [state | (args || [])] ++ [context, options])
    apply(m, :__post_handle_call__, [o, context, options] )
  end
  def handle_call(m, msg, from, state) do
    IO.inspect(msg, label: "[UNCAUGHT] CALL #{m}")
    {:reply, {:unhandled, msg}, state}
  end

  #-----------------------
  #
  #-----------------------
  def handle_cast(_, M.msg_envelope() = call, state) do
    MessageHandler.unpack_cast(call, state)
  end
  def handle_cast(m, M.s(call: M.call(handler: h, args: args), context: context, options: options), state) do
    o = apply(m, h, [state | (args || [])] ++ [context, options])
    apply(m, :__post_handle_cast__, [o, context, options] )
  end
  def handle_cast(m, msg, state) do
    IO.inspect(msg, label: "[UNCAUGHT] CAST #{m}")
    {:noreply, state}
  end

  #-----------------------
  #
  #-----------------------
  def handle_info(m, M.msg_envelope() = call, state) do
    MessageHandler.unpack_info(call, state)
  end
  def handle_info(m, M.s(call: M.call(handler: h, args: args), context: context, options: options), state) do
    o = apply(m, h, [state | (args || [])] ++ [context, options])
    apply(m, :__post_handle_info__, [o, context, options] )
  end
  def handle_info(m, msg, state) do
    IO.inspect(msg, label: "[UNCAUGHT] INFO #{m}")
    {:noreply, state}
  end

  #--------------------------------------
  # post_handle_call
  #--------------------------------------
  def __post_handle_call__(m, {:reply, reply, state}, context, options) do
    {:reply, reply, apply(m, :persist_changes, [state, context, options])}
  end
  def __post_handle_call__(m, {:reply, reply, state, term}, context, options) do
    {:reply, reply, apply(m, :persist_changes, [state, context, options]), term}
  end
  def __post_handle_call__(m, {:noreply, state}, context, options) do
    {:noreply, apply(m, :persist_changes, [state, context, options])}
  end
  def __post_handle_call__(m, {:noreply, state, term}, context, options) do
    {:noreply, apply(m, :persist_changes, [state, context, options]), term}
  end
  def __post_handle_call__(m, {:stop, reason, state}, context, options) do
    {:stop, reason, apply(m, :persist_changes, [state, context, options])}
  end
  def __post_handle_call__(m, {:stop, reason, reply, state}, context, options) do
    {:stop, reason, reply, apply(m, :persist_changes, [state, context, options])}
  end
  def __post_handle_call__(_, response, _,_), do: response


  #-----------------
  #
  #-----------------
  def __mark__(m, state, mark, context, options)
  def __mark__(_, _, :modified, _, _) do
    Process.put(:persist, true)
  end
  def __mark__(_, _, :persisted, _, _) do
    Process.put(:persist, false)
  end
  def __mark__(_,_,_,_,_), do: :nop


  #-----------------
  #
  #-----------------
  def __check__(m, state, check, context, options)
  def __check__(_,_,:modified,_,_) do
    Process.get(:persist)
  end
  def __check__(_,_,:persisted,_,_) do
    !Process.get(:persist)
  end
  def __check__(_,_,_,_,_) do
    :nop
  end

  def shallow_persist(m, worker, context, options)
  def shallow_persist(m, %{__struct__: Noizu.Service.Worker.State, worker: worker, status: :loaded} = state, context, options) do
    w = shallow_persist(m, worker, context, options)
    %{state| worker: w}
  end
  def shallow_persist(_, worker, context, options) do
    apply(@entity_repo, :update, [worker, context, options])
    worker
  end

  def persist(m, worker, context, options)
  def persist(m, %{__struct__: Noizu.Service.Worker.State, worker: worker, status: :loaded} = state, context, options) do
    w = persist(m, worker, context, options)
    %{state| worker: w}
  end
  def persist(_, worker, context, options) do
    apply(@entity_repo, :update, [worker, context, options])
  end

  #--------------------------------------
  # persist_changes
  #--------------------------------------
  def persist_changes(m, state, context, options \\ nil)
  def persist_changes(m, %{__struct__: Noizu.Service.Worker.State, worker: worker, status: :loaded} = state, context, options) do
      if persist = apply(m, :__persist__?, [state, context, options]) do
        context = apply(Noizu.Context, :system, [context])
        try do
          unless persist == :complete do
            apply(m, :shallow_persist, [worker, context, options])
            apply(m, :__mark__, [state, :persisted, context, options])
          else
            apply(@entity_repo, :update, [worker, context, options])
            apply(m, :__mark__, [state, :persisted, context, options])
          end
        rescue _ ->
          state
        catch
          :exit, _ ->
            state
          _ ->
            state
        end
      else
        state
      end
  end
  def persist_changes(_, state, _, _) do
    state
  end

  #-----------------
  #
  #-----------------
  def __persist__?(m, state,context,options) do
    cond do
      options[m][:persist_changes][:force] -> true
      options[:persist_changes][:force] -> true
      :else -> apply(m, :__check__, [state,:modified,context,options])
    end
  end

  defmacro __using__(options) do
    pool = options[:pool] || (Module.split(__CALLER__.module) |> Enum.slice(0..-2) |> Module.concat())
    quote bind_quoted: [pool: pool] do
      @behaviour Noizu.Service.Worker.Behaviour
      #@behaviour Noizu.ERP.Behaviour
      require Logger
      require Record
      require Noizu.Service.Types
      alias Noizu.Service.Types, as: M
      alias Noizu.Service.Types.Handle, as: MessageHandler
      require Noizu.EntityReference.Records
      alias Noizu.EntityReference.Records, as: R

      @pool pool
      @worker_repo Module.concat([__MODULE__, Repo])
      def __pool__(), do: @pool
      def __dispatcher__(), do: apply(__pool__(), :__dispatcher__, [])
      def __registry__(), do: apply(__pool__(), :__registry__, [])
      def recipient(M.link(recipient: R.ref(module: __MODULE__)) = link ), do: {:ok, link}
      def recipient(ref), do: ref(ref)

      def init({:ref, __MODULE__, identifier}, args, context) do
        %__MODULE__{
          identifier: identifier
        }
      end

      def load(%Noizu.Service.Worker.State{} = state, context, options \\ nil) do
        {:ok, %Noizu.Service.Worker.State{state| status: :loaded}}
      end

      def reload!(%Noizu.Service.Worker.State{} = state, context, options \\ nil) do
        with {:ok, state} <- load(state, context, options) do
          {:noreply, state}
        else
          _ -> {:noreply, state}
        end
      end

      def fetch(%Noizu.Service.Worker.State{} = state, :state, _, _) do
        {:reply, state, state}
      end
      def fetch(%Noizu.Service.Worker.State{} = state, :process, _, _) do
        {:reply, {state.identifier, node(), self()}, state}
      end

      def ping(state, _, _) do
        {:reply, :pong, state}
      end


      def wake!(state, _, _) do
        {:noreply, state}
      end

      def kill!(state, _, _) do
        {:stop, :shutdown, :ok, state}
      end

      def crash!(state, _, _) do
        throw "User Initiated Crash"
      end

      def hibernate(state, _, _) do
        {:reply, :ok, state, :hibernate}
      end

      def persist!(state, context, options) do
        {:reply, :ok, persist_changes(state, context, options)}
      end

      #====================
      # internal
      #====================
      def __mark__(state, mark, context, options) do
        apply(Noizu.Service.Worker.Behaviour, :__mark__, [__MODULE__, state, mark, context, options])
      end
      def __check__(state, check, context, options) do
        apply(Noizu.Service.Worker.Behaviour, :__check__, [__MODULE__, state, check, context, options])
      end
      def __persist__?(state,context,options) do
        apply(Noizu.Service.Worker.Behaviour, :__persist__?, [__MODULE__, state, context, options])
      end
      def shallow_persist(worker_or_state, context, options) do
        apply(Noizu.Service.Worker.Behaviour, :shallow_persist, [__MODULE__, worker_or_state, context, options])
      end
      def persist(worker_or_state, context, options) do
        apply(Noizu.Service.Worker.Behaviour, :persist, [__MODULE__, worker_or_state, context, options])
      end
      def persist_changes(state, context, options) do
        apply(Noizu.Service.Worker.Behaviour, :persist_changes, [__MODULE__, state, context, options])
      end

      #-----------------------
      #
      #-----------------------
      def handle_call(call, from, state) do
        apply(Noizu.Service.Worker.Behaviour, :handle_call, [__MODULE__, call, from, state])
      end

      #-----------------------
      #
      #-----------------------
      def handle_cast(call, state) do
        apply(Noizu.Service.Worker.Behaviour, :handle_cast, [__MODULE__, call, state])
      end

      #-----------------------
      #
      #-----------------------
      def handle_info(call, state) do
        apply(Noizu.Service.Worker.Behaviour, :handle_info, [__MODULE__, call, state])
      end

      #-----------------------
      #
      #-----------------------
      def __post_handle_call__(response, context, options) do
        apply(Noizu.Service.Worker.Behaviour, :__post_handle_call__, [__MODULE__, response, context, options])
      end

      #-----------------------
      #
      #-----------------------
      def __post_handle_cast__(response, context, options) do
        apply(Noizu.Service.Worker.Behaviour, :__post_handle_call__, [__MODULE__, response, context, options])
      end

      #-----------------------
      #
      #-----------------------
      def __post_handle_info__(response, context, options) do
        apply(Noizu.Service.Worker.Behaviour, :__post_handle_call__, [__MODULE__, response, context, options])
      end

      defoverridable [
        __pool__: 0,
        __dispatcher__: 0,
        __registry__: 0,
        recipient: 1,
        init: 3,
        load: 2,
        load: 3,

        # Call Handlers
        reload!: 2,
        reload!: 3,
        fetch: 4,
        ping: 3,
        kill!: 3,
        crash!: 3,
        hibernate: 3,
        persist!: 3,

        # Internal
        __mark__: 4,
        __check__: 4,
        __persist__?: 3,
        persist: 3,
        shallow_persist: 3,
        persist_changes: 3,

        # Routing
        handle_call: 3,
        handle_cast: 2,
        handle_info: 2,
        __post_handle_call__: 3,
        __post_handle_cast__: 3,
        __post_handle_info__: 3,
      ]
    end
  end

end
