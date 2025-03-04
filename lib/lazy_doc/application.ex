defmodule LazyDoc.Application do
  @moduledoc """

   ## Main functionality

   The module LazyDoc.Application is responsible for initiating the application process in the LazyDoc system.

   ## Description

   It provides a start function that allows for the initiation of application processes with specified start parameters. The function returns the process identifier of the newly started process, which can be utilized for further interactions within the application.
  """
  use Application

  @doc File.read!("lazy_doc/lazy_doc/application/start.md")
  def start(_start_type, _start_args) do
    {:ok, self()}
  end
end
