defmodule LazyDoc.CLI do
  @moduledoc """

  The module LazyDoc.CLI provides a command-line interface for interacting with the LazyDoc functionality.

  ## Description

  It serves as the entry point for running various tasks related to LazyDoc, such as generating documentation, checking documentation status, and cleaning up generated files. It also handles the inclusion of necessary ebin paths for modules and processes command-line arguments to determine which task to execute.
  """
  require Logger
  @doc File.read!("priv/lazy_doc/lazy_doc/cli/main.md")
  def main(args) do
    Application.ensure_all_started([:lazy_doc, :logger, :req])

    cond do
      Enum.empty?(args) ->
        Mix.Tasks.LazyDoc.run(args)

      args == ["--check"] or args == ["-c"] ->
        Mix.Tasks.LazyDoc.Check.run(args)

      args == ["--clean"] or args == ["-r"] ->
        Mix.Tasks.LazyDoc.Clean.run(args)

      args == ["--help"] or args == ["-h"] ->
        help_message()

      true ->
        help_message()
    end
  end

  defp help_message() do
    ## TO_DO: a proper error message.
    Logger.info("mom is gae")
  end
end
