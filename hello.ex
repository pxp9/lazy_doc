defmodule LazyDoc do
  @moduledoc """
  Documentation for `LazyDoc`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> LazyDoc.hello()
      :world

  """
  def hello do
    :world
  end

  @doc """

  Parameters

  - None
  Description
   Prints "Hello world" to the standard output.

  Returns
   None

  """
  def func_without_doc(), do: IO.puts("Hello world")
end
