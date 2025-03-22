defmodule Mix.Tasks.LazyDoc.Check do
  @moduledoc """

  The module Mix.Tasks.LazyDoc.Check provides a mix task for checking the documentation status of functions and modules within a project.

  ## Description

  This module is designed to facilitate the documentation process in Elixir projects by identifying undocumented functions and modules. It functions as part of the LazyDoc toolset, which aims to improve code documentation practices. When the task is executed, it starts the LazyDoc application, extracts relevant data from files, and checks for any undocumented functions or modules. It logs warnings for each undocumented function in a module and for each undocumented module, and subsequently determines whether the documentation is complete or not, exiting with an appropriate status based on its findings. The use of this module encourages developers to maintain well-documented code, enhancing overall code quality and maintainability.
  """
  require Logger
  use Mix.Task

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc.check/run.md")
  def run(args) do
    Mix.Task.run("app.config")

    main(args)
  end

  @doc false
  def main(_args) do
    values =
      LazyDoc.Util.extract_data_from_files()
      |> Enum.map(fn entry ->
        Logger.info("Checking #{entry.file}")

        get_undocumented_functions(entry.functions, entry.file) != [] or
          get_undocumented_modules(entry.modules, entry.file)
      end)

    if Enum.any?(values, fn val -> val end) do
      exit({:shutdown, 1})
    else
      exit({:shutdown, 0})
    end
  end

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc.check/get_undocumented_functions.md")
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

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc.check/print_warnings.md")
  def print_warnings(functions, mod, file) do
    Enum.each(functions, fn {:function, {name, _code}} ->
      Logger.warning("Function :#{name} in module `#{mod}` needs to be documented")
    end)

    Logger.info("file: #{file}")
  end

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc.check/get_undocumented_modules.md")
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
