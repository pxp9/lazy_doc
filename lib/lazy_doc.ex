defmodule LazyDoc do
  @moduledoc """

   ## Main functionality

   The module LazyDoc provides a way to extract and organize documentation from Elixir source files by reading them, parsing their abstract syntax tree (AST), and collecting relevant information about modules, functions, and comments.

   ## Description

   It implements functions to read files matching a given path pattern, extract their AST and comments, group function definitions by names and arities, filter out undocumented functions and modules, and retrieve associated documentation for the extracted modules. The module serves as a utility for generating or managing documentation for Elixir projects.
  """

  @doc """

  Parameters

  path_wildcard - a string pattern used to match file paths for reading.
  Description
   Reads files that match the given wildcard pattern, extracts their abstract syntax tree (AST), comments, and function definitions.

  Returns
   a list of maps containing details about each file, including the content, AST, modules, functions, and comments extracted.

  """
  def extract_data_from_files() do
    path_wildcard = Application.get_env(:lazy_doc, :path_wildcard, "lib/**/*.ex")

    Path.wildcard(path_wildcard)
    |> Enum.map(fn file ->
      # this task is for dev purposes so if we do not have a success read, it is weird.
      {:ok, content} = File.read(file)

      {:ok, ast, comments} =
        Code.string_to_quoted_with_comments(content,
          literal_encoder: &{:ok, {:__block__, &2, [&1]}},
          token_metadata: true,
          unescape: false
        )

      names_per_module =
        extract_names(ast)
        |> Enum.map(fn {:module, module_name, module_ast, code_mod, functions} ->
          {module_name |> Module.concat(), module_ast, code_mod,
           join_code_from_clauses(functions)}
        end)

      modules_to_fetch_docs =
        Enum.map(names_per_module, fn {module_name, _module_ast, _code_mod, _functions} ->
          module_name
        end)

      docs_per_module =
        docs_per_module(modules_to_fetch_docs)
        |> Enum.map(fn {module, {module_doc, func_docs}} ->
          {module, {module_doc, group_docs_different_arities(func_docs)}}
        end)

      zip_to_process =
        Enum.zip(names_per_module, docs_per_module)

      ## Basically filtering the functions just the non documented functions
      functions =
        Enum.map(zip_to_process, fn {names_module, function_docs_single_module} ->
          filter_undocumented_functions(names_module, function_docs_single_module)
        end)

      modules =
        filter_undocumented_modules(zip_to_process)

      %{
        file: file,
        content: content,
        lines: String.split(content, "\n") |> Stream.map(&String.trim/1) |> Enum.with_index(),
        ast: ast,
        functions: functions,
        modules: modules,
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
         {:defmodule, _meta, [{:__aliases__, _meta_aliases, module_name}, children]} = ast_mod,
         acc
       ) do
    children_names = extract_names(children, [])

    {modules, funcs} =
      Enum.split_with(children_names, fn elem ->
        match?({:module, _name, _name_ast, _code_mod, _children}, elem)
      end)

    modules =
      Enum.map(modules, fn {:module, name, name_ast, code_mod, child_module_children} ->
        {:module, module_name ++ name, name_ast, code_mod, child_module_children}
      end)

    [{:module, module_name, module_name, Macro.to_string(ast_mod), funcs} | acc] ++ modules
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

  list_nodes - a list containing nodes which include functions
  list_undocumented_functions - a list of functions identified as undocumented.

  Description
   Filters a list of nodes to find those that correspond to undocumented functions.

  Returns
   a list of nodes that are undocumented functions present in list_nodes.

  """
  def filter_undocumented_functions(
        {module, module_ast, _code_mod, functions},
        {_mod, {_module_doc, function_docs}}
      ) do
    ## Filter the private functions
    ## we already merged the code if it was necessary
    ## Filter the functions which at least has one of the clauses documented
    # even if it is a different arity.

    functions =
      Enum.filter(functions, fn {type, {func_name, _code}} ->
        type == :function and Enum.all?(function_docs[func_name], fn elem -> elem == :none end)
      end)

    {module, module_ast, functions}
  end

  @doc """

  ## Parameters

  - zip_to_process - a list of tuples containing module information and their documentation.

  ## Description
  Filters the given list of modules and returns those that do not have associated documentation.

  ## Returns
  A list of tuples containing modules and their respective AST and code without documentation.

  """
  def filter_undocumented_modules(zip_to_process) do
    Enum.filter(zip_to_process, fn
      {_names_module, {_mod, {module_doc, _function_docs}}} ->
        module_doc == :none
    end)
    |> Enum.map(fn
      {{module, module_ast, code_mod, _functions}, _function_docs_single_module} ->
        {module, module_ast, code_mod}
    end)
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
end
