defmodule LazyDoc.Application do
  @moduledoc """

   ## Main functionality

   The module LazyDoc.Application is responsible for initiating the application process in the LazyDoc system.

   ## Description

   It provides a start function that allows for the initiation of application processes with specified start parameters. The function returns the process identifier of the newly started process, which can be utilized for further interactions within the application.
  """
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
