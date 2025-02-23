defmodule Mix.Tasks.LazyDoc do
  alias LazyDoc.Provider

  require Logger
  use Mix.Task

  @default_function_prompt ~s(You should describe the parameters based on the spec given and give a small description of the following function.\n\nPlease do it in the following format given as an example, important do not return the header of the function, do not return a explanation of the function, your output must be only the docs in the following format.\n\n@doc """\n\n## Parameters\n\n- transaction_id - foreign key of the Transactions table.\n## Description\n Performs a search in the database\n\n## Returns\n the Transaction corresponding to transaction_id\n\n"""\n\nFunction to document:\n)

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

    {provider_mod, model} = Application.get_env(:lazy_doc, :provider)

    final_prompt =
      Application.get_env(:lazy_doc, :custom_function_prompt, @default_function_prompt)

    ## Runs the runtime.exs from the client
    Mix.Task.run("app.config")

    token = Application.get_env(:lazy_doc, :token)

    path_wildcard = Application.get_env(:lazy_doc, :path_wildcard, "lib/**/*.ex")

    LazyDoc.extract_data_from_files(path_wildcard)
    |> proccess_files(final_prompt, provider_mod, model, token)
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

  final_prompt - a string prefix to be added to each function's prompt.
  Description
   The initial text that precedes the function's string representation in the prompt.

  provider_mod - a module responsible for handling requests to the provider.
  Description
   The module which encapsulates the logic for interacting with the AI provider's API.

  model - the model identifier used to request AI-generated documentation.
  Description
   Specifies which AI model to use for generating the required documentation.

  token - an authorization token for the API requests.
  Description
   The security token needed to authenticate requests to the provider's API.

  Returns
   None
  """
  def proccess_files(entries, final_prompt, provider_mod, model, token) do
    model_text = Provider.model(provider_mod, model)

    Enum.each(entries, fn entry ->
      acc =
        Enum.reduce(entry.functions, entry.ast, fn mod_tuple, acc ->
          insert_nodes_in_module(mod_tuple, final_prompt, provider_mod, model_text, token, acc)
        end)

      # TO_DO: probably we should check if the ast_acc is the same as entry.ast
      # if true we should not write the file.
      # A simple but effective will be if entry.functions is empty
      # Do not write the file.

      write_to_file_formatted(entry.file, acc, entry.comments)
    end)
  end

  @doc """

  Parameters

  _module - the module to which the nodes will be inserted.
  module_ast - the abstract syntax tree of the module.
  functions - a list of functions to be processed.
  final_prompt - a string prompt to be appended to each function's prompt.
  provider_mod - the module responsible for making requests to the provider.
  model_text - the text representation of the model used in the request.
  token - the authentication token for the provider.
  acc - the accumulator for building the updated abstract syntax tree.

  Description
   Inserts nodes into a module based on provided functions and prompts.

  Returns
   the updated abstract syntax tree after processing the functions.

  """
  def insert_nodes_in_module(
        {_module, module_ast, functions},
        final_prompt,
        provider_mod,
        model_text,
        token,
        acc
      ) do
    Enum.reduce(functions, acc, fn {:function, {function_atom, function_stringified}}, acc_ast ->
      function_prompt = final_prompt <> function_stringified

      ## TO_DO: probably we should something here instead of just doing :ok
      {:ok, response} = Provider.request_prompt(provider_mod, function_prompt, model_text, token)

      docs = Provider.get_docs_from_response(provider_mod, response)

      ok? = docs_are_ok?(docs)

      docs_to_node(ok?, docs, acc_ast, function_atom, module_ast)
    end)
  end

  @doc false
  def docs_to_node(true, docs, acc_ast, function_atom, module_ast) do
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

  @doc false
  def docs_to_node(false, docs, _ast, _function_atom) do
    Logger.error(
      "docs are in a wrong format review your prompt\n\n this was returned by the AI: #{docs}"
    )
  end
end
