defmodule Noizu.Service.Server.DefaultServer do
  use GenServer
  require Noizu.Service.Types
  
  def start_link(id, server, context, options) do
    # IO.puts "STARTING: #{inspect server}"
    mod = server.config()[:otp][:server] || __MODULE__
    GenServer.start_link(mod, {id, server, context, options}, name: id)
    #|> IO.inspect(label: "#{server}.server start_link")
  end
  
  def init({_id, _pool, _context, _options}) do
    {:ok, :server_initial_state}
  end
  
  def server_spec(server, context, options \\ nil) do
    id = options[:id] || server
    worker = server.config()[:otp][:server] || __MODULE__
    start_params = [id, server, context, options]
    %{
      id: id,
      type: :worker,
      start: {worker, :start_link, start_params}
    }
  end

  def handle_call(msg, _from, state) do
    {:reply, {:uncaught, msg, state}, state}
  end
  def handle_cast(msg, state) do
    {:reply, {:uncaught, msg, state}, state}
  end
  def handle_info(msg, state) do
    {:reply, {:uncaught, msg, state}, state}
  end
  
end
