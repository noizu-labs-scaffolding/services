defmodule Noizu.Service.Worker.State do
  @vsn 1.0
  defstruct [
    identifier: nil,
    handler: nil,
    status: nil,
    status_info: nil,
    worker: nil,
    aux: nil,
    book_keeping: nil,
    vsn: @vsn
  ]
end