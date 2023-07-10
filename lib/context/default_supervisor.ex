defmodule Noizu.Service.DefaultSupervisor do
  use Supervisor
  def start_link(id, pool, context, options) do
    supervisor = apply(pool, :config, [])[:otp][:supervisor] || __MODULE__
    Supervisor.start_link(supervisor, {id, pool, context, options}, name: id)
  end
  
  def default_worker_target(), do: 50_000
  
  def init({_id, pool, context, options}) do
    apply(pool, :join_cluster, [self(), context, options])
    cond do
      apply(pool, :config, [])[:stand_alone] ->
        [
          apply(pool, :__server__, []) |> apply(:server_spec, [context, options])
        ]
      :else ->
        [
          {Task.Supervisor, name: apply(pool, :__task_supervisor__, [])},
          apply(pool, :__server__, []) |> apply(:server_spec, [context, options]),
          apply(pool, :__worker_supervisor__, []) |> apply(:spec, [:os.system_time(:nanosecond), pool, context, options]),
        ]
    end
    |> Supervisor.init(strategy: :one_for_one)
  end
  
  def spec(pool, context, options \\ nil) do
    id = options[:id] || pool
    supervisor = apply(pool, :config, [])[:otp][:supervisor] || __MODULE__
    start_params = [id, pool, context, options]
    %{
      id: id,
      name: id,
      type: :supervisor,
      start: {supervisor, :start_link, start_params}
    }
  end
  
  def add_worker_supervisor(pool, node, spec) do
    Supervisor.start_child({pool, node}, spec)
  end
  
end
