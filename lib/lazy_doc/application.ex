defmodule LazyDoc.Application do
  use Application

  @doc """

  Parameters

  _start_type - Specifies the type of start operation being initiated.
  _start_args - Contains additional arguments needed for starting the operation.

  Returns
   {:ok, pid} where pid is the process identifier of the newly started process.

  """
  def start(_start_type, _start_args) do
    {:ok, self()}
  end
end
