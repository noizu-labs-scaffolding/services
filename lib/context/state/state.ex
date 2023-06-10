defmodule Noizu.Service.State do
  @vsn 1.0
  defstruct [
    status: nil,
    supervisor: nil,
    pool: nil,
    component: nil,
    book_keeping: nil,
    vsn: @vsn
  ]
end