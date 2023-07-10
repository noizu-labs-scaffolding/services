defmodule Noizu.Service.Worker.Behaviour do
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
  @callback kill!(state, context, options) :: noreply_response()
  @callback crash!(state, context, options) :: noreply_response()
  @callback hibernate(state, context, options) :: noreply_response()
  @callback persist!(state, context, options) :: reply_response({:ok, state} | {:ok, term} | {:error, term})


  defmacro __using__(options) do
    pool = options[:pool] || (Module.split(__CALLER__.module) |> Enum.slice(0..-2) |> Module.concat())
    quote bind_quoted: [pool: pool] do
      @behaviour Noizu.Service.Worker.Behaviour
      #@behaviour Noizu.ERP.Behaviour
      require Noizu.Service.Types
      alias Noizu.Service.Types, as: M
      require Noizu.EntityReference.Records
      alias Noizu.EntityReference.Records, as: R

      @pool pool
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
      
      def kill!(state, _, _) do
        {:stop, :shutdown, :ok, state}
      end
      def crash!(state, _, _) do
        throw "User Initiated Crash"
      end
      def hibernate(state, _, _) do
        {:reply, :ok, state, :hibernate}
      end
      def persist!(state, _, _) do
        {:reply, :not_supported, state}
      end
      
      #-----------------------
      #
      #-----------------------
      def handle_call(M.s(call: M.call(handler: h, args: args), context: context, options: options), _, state) do
        apply(__MODULE__, h, [state| (args || []) ] ++ [context, options])
      end
      def handle_call(msg, _, state) do
        {:reply, {:unhandled, msg}, state}
      end


      def handle_cast(_, state) do
        {:noreply, state}
      end
      
      def handle_info(_, state) do
        {:noreply, state}
      end
      
      defoverridable [
        __pool__: 0,
        __dispatcher__: 0,
        __registry__: 0,
        recipient: 1,
        init: 3,
        load: 2,
        load: 3,
        reload!: 2,
        reload!: 3,
        fetch: 4,
        ping: 3,
        kill!: 3,
        crash!: 3,
        hibernate: 3,
        persist!: 3,
        handle_call: 3,
        handle_cast: 2,
        handle_info: 2,
      ]
      
    end
  end
  
#  @callback status(worker) :: term
#  @callback status_details(worker) :: term
#  @callback migrate(worker, node, context, options) :: term


end
