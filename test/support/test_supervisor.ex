defmodule Noizu.Service.Test.Supervisor do
  use Supervisor

  def start() do
    Supervisor.start_link([], [strategy: :one_for_one, name: __MODULE__, strategy: :permanent])
  end
  
  def add_service(spec) do
    Supervisor.start_child(__MODULE__, spec)
  end

end