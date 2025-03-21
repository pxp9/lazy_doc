defmodule LazyDoc.CLI do
  @moduledoc """

  The module LazyDoc.CLI provides a command-line interface for interacting with the LazyDoc functionality.

  ## Description

  It serves as the entry point for running various tasks related to LazyDoc, such as generating documentation, checking documentation status, and cleaning up generated files. It also handles the inclusion of necessary ebin paths for modules and processes command-line arguments to determine which task to execute.
  """
  @doc File.read!("priv/lazy_doc/lazy_doc/cli/main.md")
  def main(args) do
    Application.ensure_all_started([:lazy_doc, :logger, :req])

    Path.wildcard("_build/dev/lib/**/ebin/")
    |> Enum.each(fn path ->
      :code.add_path(String.to_charlist(path))
    end)

    if File.exists?("config/config.exs") do
      Config.Reader.read!("config/config.exs")[:lazy_doc]
      |> Enum.each(fn {k, v} -> Application.put_env(:lazy_doc, k, v) end)
    end

    if File.exists?("config/runtime.exs") do
      Config.Reader.read!("config/runtime.exs")[:lazy_doc]
      |> Enum.each(fn {k, v} -> Application.put_env(:lazy_doc, k, v) end)
    end

    case args do
      [] ->
        Mix.Tasks.LazyDoc.run(args)

      ["--check"] ->
        Mix.Tasks.LazyDoc.Check.run(args)

      ["--clean"] ->
        Mix.Tasks.LazyDoc.Clean.run(args)
    end
  end
end
