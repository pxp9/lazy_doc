defmodule LazyDoc.ExampleModule do
  ## This function should be returned
  def hello(param) do
    IO.puts(param)
  end

  ## This function should be returned
  def hihi() do
    hi()
    hi()
  end

  ## This function should be ignored bc is private.
  defp hi(), do: IO.puts("hi")

  ## This function should be ignored bc is hidden.
  @doc false
  def greet(), do: IO.puts("Greet")

  ## This function should be ignored bc it has docs.
  @doc """
   It says Bonjour
  """
  def bonjour, do: IO.puts("Bonjour")
end
