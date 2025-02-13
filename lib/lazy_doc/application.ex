defmodule LazyDoc.Application do
  use Application

  def start(_start_type, _start_args) do
    {:ok, self()}
  end
end
