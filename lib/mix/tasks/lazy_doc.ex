defmodule Mix.Tasks.LazyDoc do
  @moduledoc """

  The module Mix.Tasks.LazyDoc provides a Mix task for generating and inserting documentation into Elixir modules using an AI-powered provider.

  ## Description

  It orchestrates the extraction of data from source files, interacts with a specified AI provider to produce documentation for both modules and functions, and writes the generated documentation back into the respective source files. The task ensures necessary configurations such as tokens and provider parameters are validated before proceeding with the documentation generation process. Additionally, it handles file writing operations in a formatted manner and maintains the structure of the Elixir AST while inserting documentation comments.
  """
  alias LazyDoc.Provider
  alias LazyDoc.Providers.GithubAi

  require Logger
  use Mix.Task

  @default_function_prompt ~s(You should describe the parameters based on the spec given and give a small description of the following function.\n\nPlease do it in the following format given as an example, important do not return the header of the function, do not return a explanation of the function, your output must be only the docs in the following format:\n\nReturns the Transaction corresponding to transaction_id\(Initial sentence indicating what returns the function\)\n\n## Parameters\n\n- transaction_id - foreign key of the Transactions table.\n## Description\n Performs a search in the database\n\nFunction to document:\n)

  @default_module_prompt ~s(You should describe what this module does based on the code given.\n\n Please do it in the following format given as an example, important do not return the code of the module, your output must be only the docs in the following format.\n\n@moduledoc """\n\nThe module GithubAi provides a way of communicating with Github AI API \(describes the main functionality of the module\).\n\n## Description\n\nIt implements the behavior Provider a standard way to use a provider in LazyDoc.\(gives a detailed description of what the module does\)\n"""\n\nModule to document:\n)

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc/run.md")
  def run(_command_line_args) do
    ## Start req

    _result = Application.ensure_all_started([:req, :telemetry])

    LazyDoc.Util.extract_data_from_files()
    |> proccess_files()
  end

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc/docs_are_ok?.md")
  def docs_are_ok?(docs) when is_binary(docs) do
    match?("@doc \" " <> _, docs) or match?("@doc \"\"\"\n" <> _, docs)
  end

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc/write_to_file.md")
  def write_to_file(file, ast) do
    File.write(file, Macro.to_string(ast))
  end

  @doc File.read!("priv/lazy_doc/write_to_file_formatted.md")
  def write_to_file_formatted(file, compile_path, ast, comments) do
    dot_formatter = Application.get_env(:lazy_doc, :file_formatter, ".formatter.exs")

    {_func, formatter} =
      Mix.Tasks.Format.formatter_for_file(file, dot_formatter: dot_formatter)

    line_length = Keyword.get(formatter, :line_length, 98)
    locals_without_parens = Keyword.get(formatter, :locals_without_parens, [])

    to_write =
      Code.quoted_to_algebra(ast,
        comments: comments,
        escape: false,
        locals_without_parens: locals_without_parens
      )
      |> Inspect.Algebra.format(line_length)
      |> IO.iodata_to_binary()

    to_write = to_write <> "\n"

    result = File.write(file, to_write)

    ## Spawn the compiler if we managed to write the file
    if result == :ok do
      Kernel.ParallelCompiler.compile_to_path([file], compile_path)
    end
  end

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc/insert_doc_for_function.md")
  def insert_doc_for_function(ast, name_func, ast_doc, module_ast) do
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
               {:__block__, meta_inner_block, List.insert_at(block_children, index, ast_doc)}}
            ]

            {{:defmodule, meta_mod, [aliases_node, new_do_block]}, [{index, index + 1} | rest]}

          # Single node module
          {:defmodule, meta_mod,
           [
             {:__aliases__, _meta_aliases, ^module_ast} = aliases_node,
             [{{:__block__, meta_block, [:do]}, node}]
           ]} = _ast,
          acc ->
            new_do_block = [{{:__block__, meta_block, [:do]}, {:__block__, [], [ast_doc, node]}}]

            {{:defmodule, meta_mod, [aliases_node, new_do_block]}, acc}

          other, acc ->
            {other, acc}
        end
      )

    new_ast
  end

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc/proccess_files.md")
  def proccess_files(entries) do
    {provider_mod, model, params} =
      Application.get_env(
        :lazy_doc,
        :provider,
        {GithubAi, :gpt_4o_mini, [max_tokens: 2048, top_p: 1, temperature: 1]}
      )

    final_function_prompt =
      Application.get_env(:lazy_doc, :custom_function_prompt, @default_function_prompt)

    final_module_prompt =
      Application.get_env(:lazy_doc, :custom_module_prompt, @default_module_prompt)

    token = Application.get_env(:lazy_doc, :token, System.get_env("API_TOKEN"))

    if !token do
      raise ArgumentError, message: "Token is required configuration."
    end

    model_text = Provider.model(provider_mod, model)

    if not Provider.check_parameters?(provider_mod, params) do
      raise ArgumentError, message: "Invalid parameters for this provider #{inspect(params)}"
    end

    Enum.each(entries, fn entry ->
      acc =
        Enum.reduce(entry.modules, entry.ast, fn {_mod, mod_ast, code_mod}, acc_ast ->
          function_prompt = final_module_prompt <> code_mod
          ## TO_DO: probably we should something here instead of just doing :ok
          {:ok, response} =
            Provider.request_prompt(provider_mod, function_prompt, model_text, token, params)

          docs = Provider.get_docs_from_response(provider_mod, response)

          # TO_DO: check if the @module_doc is ok
          docs_to_module_doc_node(docs, acc_ast, mod_ast)
        end)

      acc =
        Enum.reduce(entry.functions, acc, fn mod_tuple, acc_ast ->
          insert_nodes_in_module(
            mod_tuple,
            final_function_prompt,
            provider_mod,
            model_text,
            token,
            params,
            acc_ast
          )
        end)

      ## We need the directory where the `beam` file after the recompilation with the docs generated should be placed.
      module_docs = not Enum.empty?(entry.modules)

      function_docs =
        not Enum.all?(entry.functions, fn {_mod, _mod_ast, functions} ->
          Enum.empty?(functions)
        end)

      write_files(module_docs or function_docs, entry, acc)
    end)
  end

  defp write_files(must_write?, entry, ast) do
    if must_write? do
      elem = Enum.at(entry.functions_documented, 0)

      compile_path =
        elem
        |> then(fn {mod, _mod_ast, _} -> mod end)
        |> :code.which()
        |> Path.relative_to_cwd()
        |> Path.dirname()

      Mix.Tasks.LazyDoc.write_to_file_formatted(entry.file, compile_path, ast, entry.comments)
    end
  end

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc/insert_nodes_in_module.md")
  def insert_nodes_in_module(
        {module, module_ast, functions},
        final_prompt,
        provider_mod,
        model_text,
        token,
        params,
        acc
      ) do
    is_external_docs = Application.get_env(:lazy_doc, :external_docs, false)

    Enum.reduce(functions, acc, fn {:function, {function_atom, function_stringified}}, acc_ast ->
      function_prompt = final_prompt <> function_stringified

      ## TO_DO: probably we should something here instead of just doing :ok
      {:ok, response} =
        Provider.request_prompt(provider_mod, function_prompt, model_text, token, params)

      docs = Provider.get_docs_from_response(provider_mod, response)

      docs = fix_docs_format(is_external_docs, module, docs, function_atom)
      docs_to_node(docs, acc_ast, function_atom, module_ast)
    end)
  end

  defp fix_docs_format(is_external_docs, module, docs, function_atom) do
    if is_external_docs do
      path =
        to_string(module.module_info(:compile)[:source])
        |> String.split("/lib")
        |> Enum.at(1)
        |> then(fn path -> "priv/lazy_doc#{path}" end)
        |> String.replace(
          ".ex",
          ""
        )

      File.mkdir_p(path)

      file = "#{path}/#{function_atom}.md"

      File.write!(file, docs)

      "@doc File.read!(\"#{file}\")"
    else
      ~s(@doc """\n\n#{docs}\n\n""")
    end
  end

  @doc false
  def docs_to_node(docs, acc_ast, function_atom, module_ast) do
    result =
      Code.string_to_quoted_with_comments(docs,
        literal_encoder: &{:ok, {:__block__, &2, [&1]}},
        token_metadata: true,
        unescape: false
      )

    case result do
      {:ok, node, _} ->
        insert_doc_for_function(acc_ast, function_atom, node, module_ast)

      {:error, reason} ->
        Logger.error("Cannot parse the response as an Elixir AST: #{inspect(reason)}")
        acc_ast
    end
  end

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc/docs_to_module_doc_node.md")
  def docs_to_module_doc_node(docs, acc_ast, module_ast) do
    result =
      Code.string_to_quoted_with_comments(docs,
        literal_encoder: &{:ok, {:__block__, &2, [&1]}},
        token_metadata: true,
        unescape: false
      )

    case result do
      {:ok, node, _} ->
        insert_module_doc(acc_ast, module_ast, node)

      {:error, reason} ->
        Logger.error("Cannot parse the response as an Elixir AST: #{inspect(reason)}")
        acc_ast
    end
  end

  @doc File.read!("priv/lazy_doc/mix/tasks/lazy_doc/insert_module_doc.md")
  def insert_module_doc(ast, module_ast, ast_doc) do
    {new_ast, _acc} =
      Macro.prewalk(
        ast,
        [],
        fn
          {:defmodule, meta_mod,
           [
             {:__aliases__, _meta_aliases, ^module_ast} = aliases_node,
             [{{:__block__, meta_block, [:do]}, {:__block__, meta_inner_block, block_children}}]
           ]},
          acc ->
            new_do_block = [
              {{:__block__, meta_block, [:do]},
               {:__block__, meta_inner_block, [ast_doc | block_children]}}
            ]

            {{:defmodule, meta_mod, [aliases_node, new_do_block]}, [:complex_mod | acc]}

          # Single node module
          {:defmodule, meta_mod,
           [
             {:__aliases__, _meta_aliases, ^module_ast} = aliases_node,
             [{{:__block__, meta_block, [:do]}, node}]
           ]} = _ast,
          acc ->
            new_do_block = [{{:__block__, meta_block, [:do]}, {:__block__, [], [ast_doc, node]}}]

            {{:defmodule, meta_mod, [aliases_node, new_do_block]}, [:simple_mod | acc]}

          other, acc ->
            {other, acc}
        end
      )

    new_ast
  end
end
