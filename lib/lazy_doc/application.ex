defmodule LazyDoc.Application do
  @moduledoc """

  The module LazyDoc.Application is responsible for managing the application lifecycle in the LazyDoc framework.

  ## Description

  It implements the behavior of an Application, specifically defining the start function which is called when the application starts. The start function currently returns the process identifier of the calling process, indicating successful initialization of the application.
  """
  use Application

  @doc File.read!("priv/lazy_doc/lazy_doc/application/start.md")
  def start(_start_type, _start_args) do
    {:ok, self()}
  end
end
