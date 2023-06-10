defmodule Noizu.Service.Server do
  
  defmacro default() do
    quote do
      defmodule Server do
        @pool Module.split(__MODULE__) |> Enum.slice(0..-2) |> Module.concat()
              #|> IO.inspect(label: :server)
        
        def __pool__(), do: @pool
        def config(), do: apply(__pool__(), :config, [])
        
        def server_spec(context, options \\ nil) do
          Noizu.Service.Server.DefaultServer.server_spec(__MODULE__, context, options)
        end

        def __dispatcher__(recipient, hint) do
          {:ok, __MODULE__}
        end
   
        
        
        
      end
    end
  end
   
   
end