defmodule Mix.Tasks.LazyDoc.Check do
  @moduledoc """

   ## Main functionality

   The module Mix.Tasks.LazyDoc.Check is designed to facilitate the checking of documentation for functions and modules within a codebase using the LazyDoc application.

   ## Description

   It initializes the LazyDoc application, identifies undocumented functions and modules across specified files, and exits with an appropriate status code based on the presence of undocumented elements. Warnings are logged for any undocumented functions and modules encountered during the check.
  """
  require Logger
  use Mix.Task

  @doc """

  ## Parameters

  - _command_line_args - arguments passed via the command line interface.

  ## Description
   Initializes the LazyDoc application, checks for undocumented functions in the specified files, and gracefully exits based on the findings.

  ## Returns
   Exits the application with a status code indicating the presence of undocumented functions (1 if found, 0 if none).
  """
  def run(_command_line_args) do
    _result = LazyDoc.Application.start("", "")

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

  @doc """

  ## Parameters

  - entry_functions - a list of tuples representing modules and their functions.
  - file - the file where the undocumented functions are being printed.

  ## Description
   Iterates through a list of entry functions and prints warnings for modules that contain undocumented functions.

  ## Returns
   a list of modules that have undocumented functions.

  """
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

  @doc """

  ## Parameters

  - functions - a list of functions to check for documentation.
  - mod - the module name where the functions are defined.
  - file - the filename where the module is located.

  ## Description
   Logs warnings for each function in the list that lacks documentation and provides information about the module and file.

  ## Returns
   nil
  """
  def print_warnings(functions, mod, file) do
    Enum.each(functions, fn {:function, {name, _code}} ->
      Logger.warning("Function :#{name} in module `#{mod}` needs to be documented")
    end)

    Logger.info("file: #{file}")
  end

  @doc """

  ## Parameters

  - modules - a list of modules to check for documentation.
  - file - the name of the file where the modules are located.

  ## Description
   Checks if the provided modules are documented and logs warnings for any undocumented modules.

  ## Returns
   true if there are undocumented modules, false otherwise.

  """
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
