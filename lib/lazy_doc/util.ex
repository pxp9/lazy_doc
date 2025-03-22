defmodule LazyDoc.Util do
  @moduledoc """

  The module LazyDoc provides an interface for extracting and processing documentation and code information from Elixir source files.

  ## Description

  It implements functionality to scan Elixir source files within a specified path, extract module and function definitions, group related functions by name (taking arity into account), and filter undocumented or documented functions and modules. The primary purpose of LazyDoc is to facilitate the automation of generating documentation by analyzing source code, managing documentation for function overloads, and providing insights into which parts of the codebase are lacking documentation.
  """
  require Logger
  @global_path "lib/**/*.ex"

  @doc File.read!("priv/lazy_doc/lazy_doc/extract_data_from_files.md")
  def extract_data_from_files() do
    patterns =
      Application.get_env(:lazy_doc, :patterns, [
        ~r"^lib(?:/[a-zA-Z_\.]+)*/[a-zA-Z_\.]+\.ex$"
      ])

    Path.wildcard(@global_path)
    |> Enum.filter(fn path ->
      Enum.any?(patterns, fn regex ->
        Regex.match?(regex, path)
      end)
    end)
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

      functions_documented =
        Enum.map(zip_to_process, fn {names_module, function_docs_single_module} ->
          filter_documented_functions(names_module, function_docs_single_module)
        end)

      modules =
        filter_undocumented_modules(zip_to_process)

      %{
        file: file,
        content: content,
        ast: ast,
        functions: functions,
        ## Used only for deleting the docs
        functions_documented: functions_documented,
        modules: modules,
        comments: comments
      }
    end)
  end

  @doc File.read!("priv/lazy_doc/lazy_doc/join_code_from_clauses.md")
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

  @doc File.read!("priv/lazy_doc/lazy_doc/extract_names.md")

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

  @doc File.read!("priv/lazy_doc/lazy_doc/filter_undocumented_functions.md")
  def filter_undocumented_functions(
        {module, module_ast, _code_mod, functions} = _module_tuple,
        {_mod, {_module_doc, function_docs}} = _mod_docs
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

  @doc File.read!("priv/lazy_doc/lazy_doc/filter_documented_functions.md")
  def filter_documented_functions(
        {module, module_ast, _code_mod, functions} = _module_tuple,
        {_mod, {_module_doc, function_docs}} = _mod_docs
      ) do
    functions =
      Enum.filter(functions, fn {type, {func_name, _code}} ->
        type == :function and
          Enum.any?(function_docs[func_name], fn elem -> elem not in [:none, :hidden] end)
      end)

    {module, module_ast, functions}
  end

  @doc File.read!("priv/lazy_doc/lazy_doc/filter_undocumented_modules.md")
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

  @doc File.read!("priv/lazy_doc/lazy_doc/docs_per_module.md")
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

  @doc File.read!("priv/lazy_doc/lazy_doc/group_docs_different_arities.md")
  def group_docs_different_arities(func_docs) do
    Enum.group_by(
      func_docs,
      fn {{:function, name, _arity}, _line, _signature, _docs, %{}} -> name end,
      fn {{:function, _name, _arity}, _line, _signature, docs, %{}} -> docs end
    )
  end

  @doc File.read!("priv/lazy_doc/lazy_doc/util/load_modules_and_conf.md")
  def load_modules_and_conf() do
    mix_env = System.get_env("MIX_ENV", "dev")
    search_target = Path.wildcard("_build/#{mix_env}/lib/**/ebin/")

    if Enum.empty?(search_target) do
      raise(
        LazyDoc.Util.NotCompiledError,
        message: "Your project must be compiled in dev mode in order to LazyDoc execute"
      )
    end

    search_target
    |> Enum.each(fn path ->
      Logger.debug("Loading #{path}")
      :code.add_path(String.to_charlist(path))
    end)

    if File.exists?("config/config.exs") do
      Config.Reader.read!("config/config.exs")[:lazy_doc]
      |> Enum.each(fn {k, v} -> Application.put_env(:lazy_doc, k, v) end)
    end

    if File.exists?("config/runtime.exs") do
      Config.Reader.read!("config/runtime.exs")[:lazy_doc]
      |> Enum.each(fn {k, v} -> Application.put_env(:lazy_doc, k, v) end)
    end
  end

  defmodule NotCompiledError do
    @moduledoc """

    The module NotCompiledError defines a custom exception that can be raised when a compilation error occurs in a program.

    ## Description

    It provides a standard way to create an exception with a customizable message, which can be used to indicate that a piece of code could not be compiled. This exception can be helpful in error handling scenarios, allowing developers to signify specific issues related to code compilation.
    """
    defexception [:message]
  end
end
