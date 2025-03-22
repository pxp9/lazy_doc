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

    LazyDoc.Util.load_modules_and_conf()

    cond do
      Enum.empty?(args) ->
        Mix.Tasks.LazyDoc.main(args)

      args == ["--check"] or args == ["-c"] ->
        Mix.Tasks.LazyDoc.Check.main(args)

      args == ["--clean"] or args == ["-r"] ->
        Mix.Tasks.LazyDoc.Clean.main(args)

      args == ["--help"] or args == ["-h"] ->
        help_message()

      true ->
        help_message()
    end
  end

  defp help_message() do
    Logger.info(
      "There are 3 options: \nuse it without any argument\n    it will document\n--check or -c\n    it will check if something is left to document\n--clean or -r\n    it will remove all the functions documentation"
    )
  end
end
