defmodule Mix.Tasks.LazyDoc.Check do
  @moduledoc """

   ## Main functionality

   The module Mix.Tasks.LazyDoc.Check is designed to facilitate the checking of documentation for functions and modules within a codebase using the LazyDoc application.

   ## Description

   It initializes the LazyDoc application, identifies undocumented functions and modules across specified files, and exits with an appropriate status code based on the presence of undocumented elements. Warnings are logged for any undocumented functions and modules encountered during the check.
  """
  require Logger
  use Mix.Task

  @doc File.read!("lazy_doc/mix/tasks/lazy_doc.check/run.md")
  def run(_command_line_args) do
    _result = LazyDoc.Application.start("", "")

    Mix.Task.run("app.config")

    values =
      LazyDoc.extract_data_from_files()
      |> Enum.map(fn entry ->
        get_undocumented_functions(entry.functions, entry.file) != [] or
          get_undocumented_modules(entry.modules, entry.file)
      end)

    if Enum.any?(values, fn val -> val end) do
      exit({:shutdown, 1})
    else
      exit({:shutdown, 0})
    end
  end

  @doc File.read!("lazy_doc/mix/tasks/lazy_doc.check/get_undocumented_functions.md")
  def get_undocumented_functions(entry_functions, file) do
    Enum.reduce(entry_functions, [], fn {mod, _mod_ast, functions} = mod_tuple, acc ->
      if functions != [] do
        print_warnings(functions, mod, file)
        [mod_tuple | acc]
      else
        acc
      end
    end)
  end

  @doc File.read!("lazy_doc/mix/tasks/lazy_doc.check/print_warnings.md")
  def print_warnings(functions, mod, file) do
    Enum.each(functions, fn {:function, {name, _code}} ->
      Logger.warning("Function :#{name} in module `#{mod}` needs to be documented")
    end)

    Logger.info("file: #{file}")
  end

  @doc File.read!("lazy_doc/mix/tasks/lazy_doc.check/get_undocumented_modules.md")
  def get_undocumented_modules(modules, file) do
    if modules != [] do
      Enum.each(modules, fn {mod, _mod_ast, _cod} ->
        Logger.warning("Module `#{mod}` needs to be documented")
        Logger.info("file: #{file}")
      end)

      true
    else
      false
    end
  end
end
