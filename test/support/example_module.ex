defmodule LazyDoc.ExampleModule do
  @type algorithms :: binary()

  ## This function should be returned
  def hello(param) do
    IO.puts(param)
  end

  ## This function should be returned
  def hihi() do
    hi()
    hi()
  end

  ## This function should be returned
  def hello_there(i) when is_atom(i), do: IO.puts("Hello there #{i}")

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

  @doc """
    Hello there
  """
  def fibs(n) do
    fibs(n, [1, 0])
  end

  def fibs(1, [a, b | rest]), do: [a + b, a, b | rest]

  def fibs(n, [a, b | rest]) do
    fibs(n - 1, [a + b, a, b | rest])
  end

  defmodule Fibs do
    def fibs(n) do
      fibs(n, [1, 0])
    end

    defp fibs(1, [a, b | rest]), do: [a + b, a, b | rest]

    defp fibs(n, [a, b | rest]) do
      fibs(n - 1, [a + b, a, b | rest])
    end

    defmodule InnerFibs do
      def inner_fibs() do
        IO.puts("fibs")
      end
    end
  end
end
