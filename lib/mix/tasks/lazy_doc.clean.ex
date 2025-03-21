defmodule Mix.Tasks.LazyDoc.Clean do
  @moduledoc """

  The module Mix.Tasks.LazyDoc.Clean provides functionality to clean up documentation generated for Elixir projects by removing uncommitted changes, checking the state of the project, and managing documentation entries in the Abstract Syntax Tree (AST).

  ## Description

  This module defines a Mix task that automates the process of cleaning documentation for functions in Elixir modules. It starts by checking for any uncommitted changes in the Git repository, exiting if such changes are found to prevent data loss. If the project is clean, it proceeds to extract relevant documentation data from source files and removes specified function documentation from the AST based on information furnished by the LazyDoc application. The updated AST is then written back to the respective source files, overwriting the previous documentation entries.

  Key functionality includes:
  - Starting the LazyDoc application.
  - Checking for a clean Git state before proceeding with documentation cleanup.
  - Extracting and processing ASTs to delete specified function documentation.
  - Writing the modified ASTs back to the original files to maintain up-to-date documentation consistency.
  """
  require Logger
  use Mix.Task

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc.clean/run.md")
  def run(_command_line_args) do

    if not clean_tree?() do
      IO.puts("Uncommitted changes detected.\nPlease stash your changes before running this task")
      exit({:shutdown, 1})
    end

    LazyDoc.Util.extract_data_from_files()
    |> Enum.each(fn entry ->
      ast =
        Enum.reduce(entry.functions_documented, entry.ast, fn {_mod, mod_ast, functions}, acc ->
          delete_function_docs_from_ast(acc, functions, mod_ast)
        end)

      functions_documented? =
        not Enum.all?(entry.functions_documented, fn {_mod, _mod_ast, functions} -> Enum.empty?(functions) end)

      if functions_documented? do
        elem = Enum.at(entry.functions_documented, 0)

        compile_path =
          elem
          |> then(fn {mod, _mod_ast, _} -> mod end)
          |> :code.which()
          |> Path.relative_to_cwd()
          |> Path.dirname()

        Mix.Tasks.LazyDoc.write_to_file_formatted(entry.file, compile_path, ast, entry.comments)
      end
    end)
  end

  defp delete_function_docs_from_ast(acc, functions, mod_ast) do
    Enum.reduce(functions, acc, fn {:function, {function_atom, _function_stringified}}, acc_ast ->
      delete_doc_from_ast(acc_ast, mod_ast, function_atom)
    end)
  end

  ## It will work if we suppose @doc is on top of the function.
  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc.clean/delete_doc_from_ast.md")
  def delete_doc_from_ast(ast, module_ast, name_func) do
    {new_ast, _acc} =
      Macro.traverse(
        ast,
        [],
        fn
          {:defmodule, _meta_mod,
           [
             {:__aliases__, _meta_aliases, ^module_ast},
             [{{:__block__, _meta_block, [:do]}, {:__block__, _meta_inner_block, block_children}}]
           ]} = ast,
          acc ->
            {ast,
             [
               Enum.find_index(block_children, fn node ->
                 match?(
                   {:def, _meta_def, [{^name_func, _meta_func, _params}, _func_children]},
                   node
                 ) or
                   match?(
                     {:def, _meta_def,
                      [
                        {:when, _meta_when, [{^name_func, _meta_func, _params}, _when_expr]},
                        _func_block
                      ]},
                     node
                   )
               end)
               | acc
             ]}

          other, acc ->
            {other, acc}
        end,
        fn
          {:defmodule, meta_mod,
           [
             {:__aliases__, _meta_aliases, ^module_ast} = aliases_node,
             [{{:__block__, meta_block, [:do]}, {:__block__, meta_inner_block, block_children}}]
           ]},
          [index | rest] ->
            new_do_block = [
              {{:__block__, meta_block, [:do]},
               {:__block__, meta_inner_block, List.delete_at(block_children, index - 1)}}
            ]

            {{:defmodule, meta_mod, [aliases_node, new_do_block]}, [{index, index - 1} | rest]}

          other, acc ->
            {other, acc}
        end
      )

    new_ast
  end

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc.clean/clean_tree?.md")
  def clean_tree?() do
    if File.exists?(".git") do
      "git"
      |> System.cmd(["diff-files", "--quiet"])
      |> clean_tree()
    else
      true
    end
  end

  defp clean_tree({_, 0}), do: true
  defp clean_tree({_, 1}), do: false
end
