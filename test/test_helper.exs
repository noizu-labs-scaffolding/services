unless node() == :"first@127.0.0.1" do
  IO.warn("YOU MUST RUN TEST SUITE VIA `./run-test` SCRIPT")
  exit(1)
end

ExUnit.configure formatters: [JUnitFormatter, ExUnit.CLIFormatter]

context = Noizu.Context.admin()
Logger.configure(level: :warn)
Application.ensure_all_started(:syn)
{:ok, _} = Noizu.Service.Test.Supervisor.start()
{:ok, _} = Noizu.Service.Test.Supervisor.add_service(Noizu.Service.ClusterManager.spec(context))
{:ok, _} = Noizu.Service.Test.Supervisor.add_service(Noizu.Service.NodeManager.spec(context))

# Launch second node
IO.puts "Launching Second Node for Routing Tests"
Noizu.Service.Test.NodeManager.start_node(:"second@127.0.0.1")

# Temporary Hack - current logic requires all nodes be aware of all other nodes, in the future we will add routing helpers
# To avoid the need to sync config across entire cluster.
# IO.puts BRING ONLINE?
#Process.sleep(5000)
Noizu.Service.NodeManager.bring_online(node(), context) |> Task.yield()
Noizu.Service.NodeManager.bring_online(:"second@127.0.0.1", context) |> Task.yield()

ExUnit.start(capture_log: true)
