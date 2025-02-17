defmodule Mix.Tasks.LazyDoc do
  alias LazyDoc.Provider

  require Logger
  use Mix.Task

  @default_function_prompt ~s(You should describe the parameters based on the spec given and give a small description of the following function.\n\nPlease do it in the following format given as an example, important do not return the header of the function, do not return a explanation of the function, your output must be only the docs in the following format.\n\n@doc """\n\nParameters\n\ntransaction_id - foreign key of the Transactions table.\nDescription\n Performs a search in the database\n\nReturns\n the Transaction corresponding to transaction_id\n\n"""\n\nFunction to document:\n)

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

    extract_data_from_files(path_wildcard)
    |> proccess_files(final_prompt, provider_mod, model, token)
  end

  @doc """

  Parameters

  ast - an abstract syntax tree (AST) structure representing the source code.
  Description
   Initiates the extraction of names from the given AST.

  Returns
   a list of names extracted from the AST.

  """
  def extract_names(ast) do
    extract_names(ast, [])
  end

  defp extract_names(ast, acc) when is_list(ast) do
    Enum.reduce(ast, acc, fn node, acc -> extract_names(node, acc) end)
  end

  defp extract_names(
         {:defmodule, _meta, [{:__aliases__, _meta_aliases, module_name}, children]},
         acc
       ) do
    [{:module, module_name}] ++ extract_names(children) ++ acc
  end

  defp extract_names({:defprotocol, _meta, [protocol_name, _]}, acc) do
    [{:protocol, protocol_name}] ++ acc
  end

  defp extract_names({:defimpl, _meta, [_protocol_name, [for: _impl_module], _]}, acc) do
    # [{:implementation, protocol_name, impl_module}] ++ acc
    ## TO_DO: not ignore this
    acc
  end

  ## TO_DO: probably here we should explore the siblings nodes until
  # the name of the function changes or it is different type of node.
  # An alternative solution will be to fix the names list after we have extracted all the names.
  defp extract_names(
         {:def, _meta_func, [{name, _meta_inner_func, _children} | _block]} = ast_fun,
         acc
       ) do
    # You might want to extract function names as well
    [{:function, {name, Macro.to_string(ast_fun)}}] ++ acc
  end

  defp extract_names({:defp, _meta, [_function_name, _clauses]}, acc) do
    # You might want to extract function names as well
    # {:function, function_name} ++ acc
    acc
  end

  defp extract_names(
         {{:__block__, _meta, _block_children}, {:__block__, _meta_inner_block, children}},
         acc
       ) do
    extract_names(children) ++ acc
  end

  defp extract_names(
         {{:__block__, _meta, _block_children}, {_whatever_op, _meta_inner_block, _children}},
         acc
       ) do
    acc
  end

  defp extract_names({_whatever, _meta, _children}, acc) do
    acc
  end

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
  write to given file the given Elixir AST
  it writes formmated the string if the Elixir AST is annotated properly.
  if the AST is taken from a string you should use this options:


  literal_encoder: &{:ok, {:__block__, &2, [&1]}},
  token_metadata: true,
  unescape: false
  """

  def write_to_file_formatted(file, ast, comments) do
    to_write =
      Code.quoted_to_algebra(ast, comments: comments, escape: false)
      |> Inspect.Algebra.format(:infinity)
      |> IO.iodata_to_binary()

    File.write(file, to_write)
  end

  @doc """
   This should work for most of the modules, it will not work if the module contains only one function because Elixir does not create a `__block__` node in this case.
  """
  def insert_doc_for_function(ast, name_func, ast_doc) do
    {new_ast, _acc} =
      Macro.traverse(
        ast,
        [],
        fn
          {:defmodule, _meta_mod, children} = ast, acc ->
            [
              _aliases_node,
              [
                {{:__block__, _meta_block, [:do]},
                 {:__block__, _meta_inner_block, block_children}}
              ]
            ] = children

            {ast,
             [
               Enum.find_index(block_children, fn node ->
                 match?(
                   {:def, _meta_def, [{^name_func, _meta_func, _params}, _func_children]},
                   node
                 )
               end)
               | acc
             ]}

          other, acc ->
            {other, acc}
        end,
        fn
          {:defmodule, meta_mod, children}, [index | rest] ->
            [
              aliases_node,
              [{{:__block__, meta_block, [:do]}, {:__block__, meta_inner_block, block_children}}]
            ] = children

            new_do_block = [
              {{:__block__, meta_block, [:do]},
               {:__block__, meta_inner_block, List.insert_at(block_children, index, ast_doc)}}
            ]

            {{:defmodule, meta_mod, [aliases_node, new_do_block]}, [{index, index + 1} | rest]}

          other, acc ->
            {other, acc}
        end
      )

    new_ast
  end

  @doc """

  Parameters

  path_wildcard - a string pattern used to match file paths for reading.
  Description
   Reads files that match the given wildcard pattern, extracts their abstract syntax tree (AST), comments, and function definitions.

  Returns
   a list of maps containing details about each file, including the content, AST, modules, functions, and comments extracted.

  """
  def extract_data_from_files(path_wildcard) do
    Path.wildcard(path_wildcard)
    |> Enum.map(fn file ->
      # this task is for dev purposes so if we do not have a success reading a file is weird.
      {:ok, content} = File.read(file)

      {:ok, ast, comments} =
        Code.string_to_quoted_with_comments(content,
          literal_encoder: &{:ok, {:__block__, &2, [&1]}},
          token_metadata: true,
          unescape: false
        )

      names = extract_names(ast) |> join_code_from_clauses()

      modules =
        Enum.filter(names, fn {whatever, _name} -> whatever == :module end)
        |> Enum.map(fn {:module, name} -> {:module, Module.concat(name)} end)

      docs_per_module = docs_per_module(modules)

      all_none_function_docs =
        Enum.reduce(docs_per_module, [], fn {:docs_v1, _annotation, _beam_language, _format,
                                             _module_doc, _metadata, function_docs},
                                            acc ->
          function_docs ++ acc
        end)

      ## Basically filtering the functions just the non documented functions
      functions = filter_undocumented_functions(names, all_none_function_docs)

      %{
        file: file,
        content: content,
        lines: String.split(content, "\n") |> Stream.map(&String.trim/1) |> Enum.with_index(),
        ast: ast,
        modules: modules,
        functions: functions,
        docs_per_module: docs_per_module,
        comments: comments
      }
    end)
  end

  @doc """

  Parameters

  names - a list of tuples where each tuple represents either a function or another type of element.
  Description
   Combines function code from the input list based on matching function names.

  Returns
   a list of tuples containing combined functions or original elements.

  """
  def join_code_from_clauses(names) do
    join_code_from_clauses(names, [])
  end

  ## End of the recursion, just 2 elements.
  def join_code_from_clauses(
        [{type_1, value_1} = elem_1, {type_2, value_2} = elem_2],
        acc
      ) do
    if type_1 == type_2 and type_1 == :function do
      {name, code_first} = value_1
      {name_2, code_second} = value_2

      if name == name_2 do
        function = {:function, {name, code_second <> "\n" <> code_first}}
        [function | acc]
      else
        [elem_1, elem_2 | acc]
      end
    else
      [elem_1, elem_2 | acc]
    end
  end

  ## Recursion case if we have 2 functions a the head of the list.
  def join_code_from_clauses(
        [
          {:function, {name, code_first}} = func_1,
          {:function, {name_2, code_second}} = func_2 | rest
        ],
        acc
      ) do
    if name == name_2 do
      function = {:function, {name, code_second <> "\n" <> code_first}}
      join_code_from_clauses([function | rest], acc)
    else
      join_code_from_clauses([func_2 | rest], [func_1 | acc])
    end
  end

  ## Recursion case if we have 2 different types of element.
  def join_code_from_clauses(
        [{:function, {_name, _code_first}} = func_1, {_other_type, _elem} = name | rest],
        acc
      ) do
    join_code_from_clauses([name | rest], [func_1 | acc])
  end

  ## Recursion case if we have 2 different types of element.
  def join_code_from_clauses(
        [{_other_type, _elem} = name, {:function, {_name, _code_first}} = func_1 | rest],
        acc
      ) do
    join_code_from_clauses([func_1 | rest], [name | acc])
  end

  @doc """

  Parameters

  list_nodes - a list containing nodes which may include functions.
  list_undocumented_functions - a list of functions identified as undocumented.

  Description
   Filters a list of nodes to find those that correspond to undocumented functions.

  Returns
   a list of nodes that are undocumented functions present in list_nodes.

  """
  def filter_undocumented_functions(list_nodes, list_undocumented_functions) do
    Enum.filter(list_nodes, fn
      {:function, {name, _stringify}} ->
        Enum.any?(list_undocumented_functions, fn
          {{:function, name_to_check, _arity}, _line, _signature, :none, %{}} ->
            name == name_to_check

          {_non_func_node, _line, [], :none, %{}} ->
            false
        end)

      {_whatever, _something} ->
        false
    end)
  end

  @spec docs_per_module([{:module, atom()}, ...]) :: [
          {:docs_v1, annotation, beam_language, format, module_doc :: doc_content, metadata,
           docs :: [doc_element]},
          ...
        ]
        when annotation: :erl_anno.anno(),
             beam_language: :elixir | :erlang | atom(),
             doc_content: %{optional(binary()) => binary()} | :none | :hidden,
             doc_element:
               {{kind :: atom(), function_name :: atom(), arity()}, annotation, signature,
                doc_content, metadata},
             format: binary(),
             signature: [binary()],
             metadata: map()

  @doc """

  Parameters

  modules - a list of modules to fetch documentation for.
  Description
   Retrieves documentation for the given modules, filtering out functions with no documentation.

  Returns
   a list of tuples containing the documentation for each module including only undocumented functions.

  """
  def docs_per_module(modules) do
    ## fetch docs get the docs info from a module
    # We should only get the function which does not contain any docs
    # docs `:hidden` means the programmer put explicitly `@doc false`
    # docs `map()` it means the is already a docs for this function.
    # docs `:none` means the script should take this function and give it to the LLM.

    Enum.map(modules, fn {:module, name} ->
      {:docs_v1, annotation, beam_language, format, module_doc, metadata, function_docs} =
        Code.fetch_docs(name)

      ## get only the function docs which are :none
      function_docs =
        Enum.filter(function_docs, fn {{_kind, _name, _arity}, _ann, _signature, docs, _meta} ->
          docs == :none
        end)

      {:docs_v1, annotation, beam_language, format, module_doc, metadata, function_docs}
    end)
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
      ast_acc =
        Enum.reduce(entry.functions, entry.ast, fn {:function,
                                                    {function_atom, function_stringified}},
                                                   acc_ast ->
          function_prompt = final_prompt <> function_stringified

          ## TO_DO: probably we should something here instead of just doing :ok
          {:ok, response} =
            Provider.request_prompt(provider_mod, function_prompt, model_text, token)

          docs = Provider.get_docs_from_response(provider_mod, response)

          ok? = docs_are_ok?(docs)

          docs_to_node(ok?, docs, acc_ast, function_atom)
        end)

      write_to_file_formatted(entry.file, ast_acc, entry.comments)
    end)
  end

  @doc false
  def docs_to_node(true, docs, acc_ast, function_atom) do
    result =
      Code.string_to_quoted_with_comments(docs,
        literal_encoder: &{:ok, {:__block__, &2, [&1]}},
        token_metadata: true,
        unescape: false
      )

    case result do
      {:ok, node, _} ->
        insert_doc_for_function(acc_ast, function_atom, node)

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
