defmodule Noizu.Service.WorkerSupervisor do
  use DynamicSupervisor
 
  
  def start_link(pool, context, options) do
    DynamicSupervisor.start_link(__MODULE__, {pool, context, options})
    #|> IO.inspect(label: "#{pool}.worker.supervisor start_link")
  end

  def init({pool, context, options}) do
    Noizu.Service.NodeManager.register_worker_supervisor(pool, self(), context, options)
    DynamicSupervisor.init(strategy: :one_for_one)
  end
  
  def spec(identifier, pool, context, options) do
    %{
      id: identifier,
      type: :supervisor,
      start: {__MODULE__, :start_link, [pool, context, options]}
    }
  end
  
  def add_worker(sup, spec) do
    DynamicSupervisor.start_child(sup, spec)
    #|> IO.inspect(label: "worker.supervisor start_child")
  end

end