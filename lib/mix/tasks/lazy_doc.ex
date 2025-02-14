defmodule Mix.Tasks.LazyDoc do
  require Logger
  use Mix.Task

  @default_function_prompt "You should describe the parameters based on the spec given and give a small description of the following function.\n\nPlease do it in the following format given as an example, important do not return the header of the function, do not return a explanation of the function, your output must be only the docs in the following format.\n\n@doc \"\"\"\n\nParameters\n\ntransaction_id - foreign key of the Transactions table.\nDescription\n Performs a search in the database\n\nReturns\n the Transaction corresponding to transaction_id\n\n\"\"\"\n\nFunction to document:\n"

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

    _result = Req.Application.start("", "")

    _result = LazyDoc.Application.start("", "")

    {provider, model} = Application.get_env(:lazy_doc, :provider)
    model_text = models(provider, model)

    final_prompt =
      Application.get_env(:lazy_doc, :custom_function_prompt, @default_function_prompt)

    ## Runs the runtime.exs from the client
    Mix.Task.run("app.config")

    token = Application.get_env(:lazy_doc, :token)

    path_wildcard = Application.get_env(:lazy_doc, :path_wildcard, "lib/**/*.ex")

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

      names = extract_names(ast)

      modules =
        Enum.filter(names, fn {whatever, _name} -> whatever == :module end)
        |> Enum.map(fn {:module, name} -> {:module, Module.concat(name)} end)

      ## fetch docs get the docs info from a module
      # We should only get the function which does not contain any docs
      # docs `:hidden` means the programmer put explicitly `@doc false`
      # docs `map()` it means the is already a docs for this function.
      # docs `:none` means the script should take this function and give it to the LLM.
      docs_per_module =
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

      all_none_function_docs =
        Enum.reduce(docs_per_module, [], fn {:docs_v1, _annotation, _beam_language, _format,
                                             _module_doc, _metadata, function_docs},
                                            acc ->
          function_docs ++ acc
        end)

      ## Basically filtering the functions just the non documented functions
      functions =
        Enum.filter(names, fn {whatever, _something} -> whatever == :function end)
        |> Enum.filter(fn {:function, {name, _stringify}} ->
          Enum.any?(all_none_function_docs, fn
            {{:function, name_to_check, _arity}, _line, _signature, :none, %{}} ->
              name == name_to_check

            {_non_func_node, _line, [], :none, %{}} ->
              false
          end)
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
    |> Enum.each(fn entry ->
      IO.inspect(entry.modules)
      IO.inspect(entry.docs_per_module)
      IO.inspect(entry.functions)
      IO.inspect(entry.lines)

      ast_acc =
        Enum.reduce(entry.functions, entry.ast, fn {:function,
                                                    {function_atom, function_stringified}},
                                                   acc_ast ->
          function_prompt = final_prompt <> function_stringified
          IO.inspect(function_prompt)

          response = request_prompt(function_prompt, provider, model_text, token)

          docs = get_docs_from_response(response)

          ok? = docs_are_ok?(docs)

          if ok? do
            result =
              Code.string_to_quoted_with_comments(docs,
                literal_encoder: &{:ok, {:__block__, &2, [&1]}},
                token_metadata: true,
                unescape: false
              )

            case result do
              {:ok, node, _} ->
                IO.inspect(node)

                insert_doc_for_function(acc_ast, function_atom, node)

              {:error, reason} ->
                IO.puts("Cannot parse the response as an Elixir AST: #{inspect(reason)}")
                acc_ast
            end
          else
            Logger.error(
              "docs are in a wrong format review your model #{model} or your prompt\n\n this was returned by the AI: #{docs}"
            )
          end
        end)

      write_to_file_formatted(entry.file, ast_acc, entry.comments)
    end)
  end

  @github_ai_endpoint "https://models.github.ai/inference/chat/completions"
  defp request_prompt(message, :github, model, token) do
    body = %{
      max_tokens: 2048,
      messages: [
        %{"role" => "system", "content" => ""},
        %{"role" => "user", "content" => message}
      ],
      model: "#{model}",
      temperature: 1,
      top_p: 1
    }

    Req.Request.new(url: @github_ai_endpoint, options: [json: body, receive_timeout: 240_000])
    |> Req.Request.put_header("Accept", "application/json")
    |> Req.Request.put_header("Content-Type", "application/json;charset=UTF-8")
    |> Req.Request.put_header("Authorization", "Bearer #{token}")
    |> Req.Steps.encode_body()
    |> Req.post!()
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

  defp github_models(model) do
    case model do
      :codestral -> "Codestral-2501"
      :gpt_4o -> "gpt-4o"
      :gpt_4o_mini -> "gpt-4o-mini"
    end
  end

  defp models(:github, model) do
    github_models(model)
  end

  defp get_docs_from_response(%Req.Response{body: body} = _response) do
    map = Jason.decode!(body) |> dbg()
    ## Take always first choice
    message = Enum.at(map["choices"], 0)["message"]["content"]
    message
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
end
