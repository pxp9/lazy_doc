defmodule Mix.Tasks.LazyDoc do
  @moduledoc """

   ## Main functionality

   The module Mix.Tasks.LazyDoc provides a Mix task for processing source files to extract and format documentation for Elixir modules and functions.

   ## Description

   It enables the extraction of documentation using AI to enhance the documentation generation process, verifying and formatting documentation as per specified requirements. It handles reading the source code, interacting with a provider for documentation prompts, and writing the results back in a structured format.
  """
  alias LazyDoc.Provider

  require Logger
  use Mix.Task

  @default_function_prompt ~s(You should describe the parameters based on the spec given and give a small description of the following function.\n\nPlease do it in the following format given as an example, important do not return the header of the function, do not return a explanation of the function, your output must be only the docs in the following format.\n\n## Parameters\n\n- transaction_id - foreign key of the Transactions table.\n## Description\n Performs a search in the database\n\n## Returns\n the Transaction corresponding to transaction_id\n\nFunction to document:\n)

  @default_module_prompt ~s(You should describe what this module does based on the code given.\n\n Please do it in the following format given as an example, important do not return the code of the module, your output must be only the docs in the following format.\n\n@moduledoc """\n\n ## Main functionality\n\n The module GithubAi provides a way of communicating with Github AI API.\n\n ## Description\n\n It implements the behavior Provider a standard way to use a provider in LazyDoc.\n"""\n\nModule to document:\n)

  @doc """

  Parameters

  _command_line_args - command line arguments provided to the function.
  Description
   Runs the main application logic for the LazyDoc utility, processing source files to extract documentation.

  Returns
   None

  """
  def run(_command_line_args) do
    ## Start req

    _result = Application.ensure_started(:telemetry)

    _result = Req.Application.start("", "")

    _result = LazyDoc.Application.start("", "")

    ## Runs the runtime.exs from the client
    Mix.Task.run("app.config")

    LazyDoc.extract_data_from_files()
    |> proccess_files()
  end

  @doc """

  Parameters

  docs - a string representing the documentation to be validated.
  Description
   Checks if the provided documentation format is correct.

  Returns
   true if the documentation is formatted correctly, false otherwise.

  """
  def docs_are_ok?(docs) when is_binary(docs) do
    match?("@doc \" " <> _, docs) or match?("@doc \"\"\"\n" <> _, docs)
  end

  @doc """
  write to given file the given Elixir AST
  This function does not write it in the proper format and it will remove comments as well
  """
  def write_to_file(file, ast) do
    File.write(file, Macro.to_string(ast))
  end

  @doc """

  ## Parameters

  - file - the name of the file where the formatted content will be written.
  - ast - the abstract syntax tree representation of the code to be written.
  - comments - optional comments to include with the formatted output.

  ## Description
   Formats the given abstract syntax tree (AST) and writes it to the specified file, including any provided comments.

  ## Returns
   :ok if the write operation is successful, or {:error, reason} if it fails.

  """
  def write_to_file_formatted(file, ast, comments) do
    line_length = Application.get_env(:lazy_doc, :line_length, 98)

    to_write =
      Code.quoted_to_algebra(ast, comments: comments, escape: false)
      |> Inspect.Algebra.format(line_length)
      |> IO.iodata_to_binary()

    to_write = to_write <> "\n"

    File.write(file, to_write)
  end

  @doc """
   This should work for most of the modules, it will not work if the module contains only one function because Elixir does not create a `__block__` node in this case.
  """
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

  @doc """

  Parameters

  entries - a list of entry structures containing functions and associated ASTs.
  Description
   A list of entries to process, transforming functions based on model responses.

  Returns
   None
  """
  def proccess_files(entries) do
    {provider_mod, model, params} = Application.get_env(:lazy_doc, :provider)

    final_function_prompt =
      Application.get_env(:lazy_doc, :custom_function_prompt, @default_function_prompt)

    final_module_prompt =
      Application.get_env(:lazy_doc, :custom_module_prompt, @default_module_prompt)

    token = Application.get_env(:lazy_doc, :token)

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

      # TO_DO: probably we should check if the ast_acc is the same as entry.ast
      # if true we should not write the file.
      # A simple but effective will be if entry.functions is empty
      # Do not write the file.

      write_to_file_formatted(entry.file, acc, entry.comments)
    end)
  end

  @doc File.read!("lazy_doc/mix/tasks/lazy_doc/insert_nodes_in_module.md")
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

      docs =
        if is_external_docs do
          path =
            to_string(module.module_info(:compile)[:source])
            |> String.split("/lib")
            |> Enum.at(1)
            |> then(fn path -> "lazy_doc#{path}" end)
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
        |> dbg()

      docs_to_node(docs, acc_ast, function_atom, module_ast)
    end)
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

  @doc """

  ## Parameters

  - docs - the documentation string to be converted to an abstract syntax tree (AST).
  - acc_ast - the accumulator AST to which the new documentation will be added.
  - module_ast - the AST of the module where the documentation will be inserted.

  ## Description
   Converts a documentation string into an Elixir AST and inserts it into the specified module's AST.

  ## Returns
   the updated accumulator AST after inserting the new documentation.
  """
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

  @doc """

  ## Parameters

  - ast - the Abstract Syntax Tree (AST) representing the module structure.
  - module_ast - the AST representation of the specific module to be modified.
  - ast_doc - a documentation string or AST node to be inserted into the module.

  ## Description
  Inserts documentation into a specified module in the AST by traversing and modifying the module's structure.

  ## Returns
  The modified AST with the new documentation inserted.

  """
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
