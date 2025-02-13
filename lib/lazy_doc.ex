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

  def func_without_doc(), do: IO.puts("Hello world")
end
