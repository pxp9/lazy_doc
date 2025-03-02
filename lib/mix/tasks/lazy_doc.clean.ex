defmodule Mix.Tasks.LazyDoc.Clean do
  require Logger
  use Mix.Task

  def run(_command_line_args) do
    _result = LazyDoc.Application.start("", "")

    Mix.Task.run("app.config")

    LazyDoc.extract_data_from_files()
    |> Enum.each(fn entry ->
      ast =
        Enum.reduce(entry.functions_documented, entry.ast, fn {_mod, mod_ast, functions}, acc ->
          Enum.reduce(functions, acc, fn {:function, {function_atom, _function_stringified}},
                                         acc_ast ->
            delete_doc_from_ast(acc_ast, mod_ast, function_atom)
          end)
        end)

      Mix.Tasks.LazyDoc.write_to_file_formatted(entry.file, ast, entry.comments)
    end)
  end

  ## It will work if we suppose @doc is on top of the function.
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
end
