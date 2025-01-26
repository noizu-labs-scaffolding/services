#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2023 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.Service.Support.TestPool do
  use Noizu.Service
  Noizu.Service.Server.default()
  
  def __worker__(), do: Noizu.Service.Support.TestPool.Worker
  
  def test(identifier, context) do
    s_call!(identifier, :test, [], context)
  end
end

defmodule Noizu.Service.Support.TestPool.Worker do
  require Noizu.Service.Types
  import Noizu.Service.Types
  alias Noizu.Service.Types, as: M
  alias Noizu.Service.Types.Handle, as: MessageHandler
  
  defstruct [
    id: nil,
    test: 0
  ]
  use Noizu.Service.Worker.Behaviour
  

  def ref({:ref, __MODULE__, _} = ref), do: {:ok, ref}
  def ref(ref) when is_integer(ref), do: {:ok, {:ref, __MODULE__, ref}}
  def ref(%__MODULE__{id: id}), do: {:ok, {:ref, __MODULE__, id}}
  def ref(ref), do: {:error, {:unsupported, ref}}
  
  #-----------------------
  #
  #-----------------------
  def handle_call(msg_envelope() = call, from, state) do
    MessageHandler.unpack_call(call, from, state)
  end
  def handle_call(s(call: call(handler: h, args: args), context: context, options: options), _, state) do
    apply(__MODULE__, h, [state|(args ||[])] ++ [context, options])
  end
  def handle_call(msg, from, state) do
    super(msg, from, state)
  end

  #-----------------------
  #
  #-----------------------
  def handle_cast(msg_envelope() = call, state) do
    MessageHandler.unpack_cast(call, state)
  end
  def handle_cast(msg, state) do
    super(msg, state)
  end

  #-----------------------
  #
  #-----------------------
  def handle_info(msg_envelope() = call, state) do
    MessageHandler.unpack_info(call, state)
  end
  def handle_info(msg, state) do
    super(msg, state)
  end
  
  #-----------------------
  #
  #-----------------------
  def test(state = %Noizu.Service.Worker.State{}, _context, _options) do
    state = state
            |>update_in([Access.key(:worker), Access.key(:test)], &(&1 + 1))
    {:reply, state.worker.test, state}
  end
  
end
