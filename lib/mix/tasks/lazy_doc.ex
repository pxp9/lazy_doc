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
  # TO_DO: support defprotocol and defimpl
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
    children_names = extract_names(children, [])

    {modules, funcs} =
      Enum.split_with(children_names, fn elem ->
        match?({:module, _name, _name_ast, _children}, elem)
      end)

    modules =
      Enum.map(modules, fn {:module, name, name_ast, child_module_children} ->
        {:module, module_name ++ name, name_ast, child_module_children}
      end)

    [{:module, module_name, module_name, funcs} | acc] ++ modules
  end

  defp extract_names({:defprotocol, _meta, [protocol_name, _]}, acc) do
    [{:protocol, protocol_name}] ++ acc
  end

  defp extract_names({:defimpl, _meta, [_protocol_name, [for: _impl_module], _]}, acc) do
    # [{:implementation, protocol_name, impl_module}] ++ acc
    ## TO_DO: not ignore this
    acc
  end

  defp extract_names(
         {:def, _meta_def,
          [{:when, _meta_when, [{name, _meta_func, _params}, _when_expr]}, _func_block]} =
           ast_fun,
         acc
       ) do
    [{:function, {name, Macro.to_string(ast_fun)}} | acc]
  end

  defp extract_names(
         {:defp, _meta_def,
          [{:when, _meta_when, [{name, _meta_func, _params}, _when_expr]}, _func_block]} =
           ast_fun,
         acc
       ) do
    [{:function_p, {name, Macro.to_string(ast_fun)}} | acc]
  end

  defp extract_names(
         {:def, _meta_func, [{name, _meta_inner_func, _children} | _block]} = ast_fun,
         acc
       ) do
    [{:function, {name, Macro.to_string(ast_fun)}} | acc]
  end

  defp extract_names(
         {:defp, _meta_func, [{name, _meta_inner_func, _children} | _block]} = ast_fun,
         acc
       ) do
    [{:function_p, {name, Macro.to_string(ast_fun)}} | acc]
  end

  defp extract_names(
         {{:__block__, _meta, _block_children}, {:__block__, _meta_inner_block, children}},
         acc
       ) do
    extract_names(children) ++ acc
  end

  ### Explore module with a single node which is a function
  defp extract_names(
         {{:__block__, _meta, _block_children}, {:def, _meta_inner_block, _children} = node},
         acc
       ) do
    extract_names([node]) ++ acc
  end

  ### Explore module with a single node which is a function
  defp extract_names(
         {{:__block__, _meta, _block_children}, {:defp, _meta_inner_block, _children} = node},
         acc
       ) do
    extract_names([node]) ++ acc
  end

  ## Ignore children from function blocks
  defp extract_names(
         {{:__block__, _meta, _block_children}, {_whatever_op, _meta_inner_block, _children}},
         acc
       ) do
    acc
  end

  defp extract_names({_whatever, _meta, _children}, acc) do
    acc
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

      names_per_module =
        extract_names(ast)
        |> Enum.map(fn {:module, module_name, module_ast, functions} ->
          {module_name |> Module.concat(), module_ast, join_code_from_clauses(functions)}
        end)

      modules =
        Enum.map(names_per_module, fn {module_name, _module_ast, _functions} -> module_name end)

      docs_per_module =
        docs_per_module(modules)
        |> Enum.map(fn {module, {module_doc, func_docs}} ->
          {module, {module_doc, group_docs_different_arities(func_docs)}}
        end)

      ## Basically filtering the functions just the non documented functions
      #
      functions =
        Enum.zip(names_per_module, docs_per_module)
        |> Enum.map(fn {names_module, function_docs_single_module} ->
          filter_undocumented_functions(names_module, function_docs_single_module)
        end)

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

  names - a list of tuples where each tuple contains a type and a value. The type indicates the kind of element (e.g., :function) and the value is related to that type.
  Description
   Joins code from function clauses based on their names, merging the code of functions with the same name.

  Returns
   a list of elements where functions with the same name are combined into a single tuple with their code concatenated.
  """
  def join_code_from_clauses(names) do
    join_code_from_clauses(names, [])
  end

  ## End of the recursion, just 2 elements.
  defp join_code_from_clauses(
         [],
         _acc
       ) do
    []
  end

  defp join_code_from_clauses(
         [{_type_1, {_name_1, _code_first}} = elem_1],
         acc
       ) do
    [elem_1 | acc]
  end

  defp join_code_from_clauses(
         [{type_1, {name_1, code_first}} = elem_1, {type_2, {name_2, code_second}} = elem_2],
         acc
       ) do
    if name_1 == name_2 do
      function = resulting_function_merge(type_1, type_2, name_1, code_first, code_second)
      [function | acc]
    else
      [elem_1, elem_2 | acc]
    end
  end

  defp join_code_from_clauses(
         [
           {type_1, {name_1, code_first}} = elem_1,
           {type_2, {name_2, code_second}} = elem_2 | rest
         ],
         acc
       ) do
    if name_1 == name_2 do
      function = resulting_function_merge(type_1, type_2, name_1, code_first, code_second)
      join_code_from_clauses([function | rest], acc)
    else
      join_code_from_clauses([elem_2 | rest], [elem_1 | acc])
    end
  end

  defp resulting_function_merge(type_1, type_2, name, code_first, code_second) do
    cond do
      type_1 == :function and type_2 == :function_p ->
        {:function, {name, code_second <> "\n" <> code_first}}

      type_1 == :function and type_2 == :function ->
        {:function, {name, code_second <> "\n" <> code_first}}

      type_1 == :function_p and type_2 == :function_p ->
        {:function_p, {name, code_second <> "\n" <> code_first}}

      type_1 == :function_p and type_2 == :function ->
        {:function, {name, code_second <> "\n" <> code_first}}
    end
  end

  @doc """

  Parameters

  func_docs - a list of function documentation tuples, where each tuple contains the function name, line number, signature, and documentation string.
  Description
   Groups function documentation by their names in order to organize and access documentation for functions with different arities.

  Returns
   a map where the keys are function names and the values are lists of their corresponding documentation strings.
    
  """
  def group_docs_different_arities(func_docs) do
    Enum.group_by(
      func_docs,
      fn {{:function, name, _arity}, _line, _signature, _docs, %{}} -> name end,
      fn {{:function, _name, _arity}, _line, _signature, docs, %{}} -> docs end
    )
  end

  @doc """

  Parameters

  list_nodes - a list containing nodes which include functions
  list_undocumented_functions - a list of functions identified as undocumented.

  Description
   Filters a list of nodes to find those that correspond to undocumented functions.

  Returns
   a list of nodes that are undocumented functions present in list_nodes.

  """
  def filter_undocumented_functions(
        {module, module_ast, functions},
        {_mod, {_module_doc, function_docs}}
      ) do
    ## Filter the private functions
    ## we already merged the code if it was necessary
    ## Filter the functions which at least has one of the clauses documented
    # even if it is a different arity.
    #

    functions =
      Enum.filter(functions, fn {type, {func_name, _code}} ->
        type == :function and Enum.all?(function_docs[func_name], fn elem -> elem == :none end)
      end)

    {module, module_ast, functions}
  end

  @spec docs_per_module([module(), ...]) :: [
          {module :: module(), module_doc :: doc_content, docs :: [doc_element]},
          ...
        ]
        when annotation: :erl_anno.anno(),
             doc_content: %{optional(binary()) => binary()} | :none | :hidden,
             doc_element:
               {{kind :: atom(), function_name :: atom(), arity()}, annotation, signature,
                doc_content, metadata},
             signature: [binary()],
             metadata: map()

  @doc """

  Parameters

  modules - a list of modules to fetch documentation for.
  Description
   Retrieves documentation for the given modules, filtering out functions with no documentation.

  Returns
   a list of tuples containing the documentation for each module including functions.

  """
  def docs_per_module(modules) do
    Enum.map(modules, fn module ->
      {:docs_v1, _annotation, _beam_language, _format, module_doc, _metadata, function_docs} =
        Code.fetch_docs(module)

      ## TO_DO: support @type docs
      function_docs =
        Enum.filter(function_docs, fn {{type, _name, _arity}, _line, _signature, _docs, %{}} ->
          type == :function
        end)

      {module, {module_doc, function_docs}}
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
