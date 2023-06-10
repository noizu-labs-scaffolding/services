defmodule Noizu.Service.Test.NodeManager do

  def start_node(name) do
    System.put_env("MIX_ENV", "test")
    task = Task.async(fn() ->
      cmd = "elixir"
      args = ["--name", "#{name}", "--cookie", "#{Node.get_cookie()}", "-S", "mix", "test_node", "#{node()}"]
      System.cmd(cmd, args)
    end)
    :ok = Noizu.Service.Helpers.wait_for_condition(fn() -> Node.ping(name) == :pong end)
    task
  end

end