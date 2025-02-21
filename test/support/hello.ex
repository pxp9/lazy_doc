defmodule LazyDoc.ExampleModule.Generated do
  @type algorithms :: binary()
  @doc """

  Parameters

  param - a value that will be printed to the console.
  Description
   Outputs the provided parameter to the standard output.

  Returns
   None

  """

  ## This function should be returned
  def hello(param) do
    IO.puts(param)
  end

  @doc """

  Parameters

  None
  Description
   Executes the function hi() twice.

  Returns
   None

  """

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
    @doc """

    Parameters

    n - integer representing the position in the Fibonacci sequence to be calculated.
    Description
     Computes Fibonacci numbers using a tail-recursive approach.

    Returns
     a list of Fibonacci numbers up to the nth position.

    """
    def fibs(n) do
      fibs(n, [1, 0])
    end

    defp fibs(1, [a, b | rest]), do: [a + b, a, b | rest]

    defp fibs(n, [a, b | rest]) do
      fibs(n - 1, [a + b, a, b | rest])
    end

    defmodule InnerFibs do
      @doc """

      Parameters

      None
      Description
       Prints the string "fibs" to the console.

      Returns
       None

      """
      def inner_fibs() do
        IO.puts("fibs")
      end
    end
  end
end
