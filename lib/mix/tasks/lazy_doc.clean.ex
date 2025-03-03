defmodule Mix.Tasks.LazyDoc.Clean do
  @moduledoc """

   ## Main functionality

   The module Mix.Tasks.LazyDoc.Clean provides a task for cleaning up documentation in the codebase.

   ## Description

   It implements functionality for removing documentation for specific functions from the abstract syntax tree (AST) of Elixir modules. The task starts the LazyDoc application, checks the application configuration, extracts documentation data from files, and processes each entry to remove the documentation for specified functions, updating the files accordingly.
  """
  require Logger
  use Mix.Task

  @doc File.read!("lazy_doc/mix/tasks/lazy_doc.clean/run.md")
  def run(_command_line_args) do
    _result = LazyDoc.Application.start("", "")

    Mix.Task.run("app.config")

    if not clean_tree?() do
      IO.("Uncommitted changes detected.\nPlease stash your changes before running this task")

      exit({:shutdown, 1})
    end

    LazyDoc.extract_data_from_files()
    |> Enum.each(fn entry ->
      ast =
        Enum.reduce(entry.functions_documented, entry.ast, fn {_mod, mod_ast, functions}, acc ->
          delete_function_docs_from_ast(acc, functions, mod_ast)
        end)

      Mix.Tasks.LazyDoc.write_to_file_formatted(entry.file, ast, entry.comments)
    end)
  end

  defp delete_function_docs_from_ast(acc, functions, mod_ast) do
    Enum.reduce(functions, acc, fn {:function, {function_atom, _function_stringified}}, acc_ast ->
      delete_doc_from_ast(acc_ast, mod_ast, function_atom)
    end)
  end

  ## It will work if we suppose @doc is on top of the function.
  @doc File.read!("lazy_doc/mix/tasks/lazy_doc.clean/delete_doc_from_ast.md")
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

  def clean_tree?() do
    "git"
    |> System.cmd(["diff-files", "--quiet"])
    |> clean_tree()
  rescue
    ErlangError -> true
  end

  defp clean_tree({_, 0}), do: true
  defp clean_tree({_, 1}), do: false
end
