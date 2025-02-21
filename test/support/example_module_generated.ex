defmodule LazyDoc.ExampleModuleGenerated do
  @type algorithms :: binary()
  @doc """

  Parameters

  param - the string to be printed.
  Description
   Outputs the provided string to the console.

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
   This function calls the `hi` function twice.

  Returns
   None

  """

  ## This function should be returned
  def hihi() do
    hi()
    hi()
  end

  @doc """

  Parameters

  i - an atom representing a name or identifier.
  Description
   Outputs a greeting message that includes the atom.

  Returns
   None

  """

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
    @doc """

    Parameters

    n - The index in the Fibonacci sequence to compute.
    Description
     Computes the Fibonacci sequence up to the n-th number.

    Returns
     A list containing the Fibonacci sequence up to the n-th element.

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
