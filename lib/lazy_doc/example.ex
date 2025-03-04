defmodule LazyDoc.Example do
  @moduledoc """
  Documentation for `LazyDoc`.

  This module is an example of autogenerated docs by
  the task provided.
  """

  @doc File.read!("priv/lazy_doc/lazy_doc/example/my_func_2.md")

  ## This comment is just to ilustrate that the algorithm will
  ## take the comments

  def my_func_2(1) do
    "is one"
  end

  def my_func_2(2) do
    "is two"
  end

  def my_func_2(n) do
    "is #{inspect(n)}"
  end

  @doc File.read!("priv/lazy_doc/lazy_doc/example/hello.md")
  def hello do
    :world
  end

  @doc File.read!("priv/lazy_doc/lazy_doc/example/func_without_doc.md")
  def func_without_doc(), do: IO.puts("Hello world")

  @doc File.read!("priv/lazy_doc/lazy_doc/example/my_func.md")
  def my_func(1) do
    "is one"
  end

  def my_func(2) do
    "is two"
  end

  def my_func(n) do
    "is #{inspect(n)}"
  end
end
