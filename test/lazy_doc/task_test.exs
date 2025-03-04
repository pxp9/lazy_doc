defmodule LazyDoc.TaskTest do
  use ExUnit.Case

  alias Mix.Tasks.LazyDoc, as: TaskLazyDoc

  test "extract the names of a module" do
    {:ok, content} = File.read("lib/lazy_doc/example.ex")

    {:ok, ast, comments} =
      Code.string_to_quoted_with_comments(content,
        literal_encoder: &{:ok, {:__block__, &2, [&1]}},
        token_metadata: true,
        unescape: false
      )

    [{:module, _module_name, _module_ast, functions}] =
      expected_names = [
        {:module, [:LazyDoc, :Example], [:LazyDoc, :Example],
         [
           function: {:my_func, "def my_func(n) do\n  \"is \#{inspect(n)}\"\nend"},
           function: {:my_func, "def my_func(2) do\n  \"is two\"\nend"},
           function: {:my_func, "def my_func(1) do\n  \"is one\"\nend"},
           function: {:func_without_doc, "def func_without_doc(), do: IO.puts(\"Hello world\")"},
           function: {:hello, "def hello do\n  :world\nend"},
           function: {:my_func_2, "def my_func_2(n) do\n  \"is \#{inspect(n)}\"\nend"},
           function: {:my_func_2, "def my_func_2(2) do\n  \"is two\"\nend"},
           function: {:my_func_2, "def my_func_2(1) do\n  \"is one\"\nend"}
         ]}
      ]

    name_extraction =
      LazyDoc.extract_names(ast)
      |> Enum.map(fn {:module, mod, mod, _code_mod, functions} ->
        {:module, mod, mod, functions}
      end)

    assert name_extraction == expected_names

    commets_texts = comments |> Enum.map(fn c -> c.text end)

    expected_comments = [
      "## This comment is just to ilustrate that the algorithm will",
      "## take the comments"
    ]

    assert commets_texts == expected_comments

    names_with_clauses_joined = functions |> LazyDoc.join_code_from_clauses()

    expected_names =
      [
        function:
          {:my_func_2,
           "def my_func_2(1) do\n  \"is one\"\nend\ndef my_func_2(2) do\n  \"is two\"\nend\ndef my_func_2(n) do\n  \"is \#{inspect(n)}\"\nend"},
        function: {:hello, "def hello do\n  :world\nend"},
        function: {:func_without_doc, "def func_without_doc(), do: IO.puts(\"Hello world\")"},
        function:
          {:my_func,
           "def my_func(1) do\n  \"is one\"\nend\ndef my_func(2) do\n  \"is two\"\nend\ndef my_func(n) do\n  \"is \#{inspect(n)}\"\nend"}
      ]

    assert names_with_clauses_joined == expected_names
  end

  test "docs per module" do
    docs_per_module = LazyDoc.docs_per_module([LazyDoc.Example])

    # This module is full documented so it returns none functions, it just returns the @module_doc
    # maybe returning the module_doc is wrong when we implement the @module_doc

    expected_result =
      [
        {LazyDoc.Example,
         {%{
            "en" =>
              "Documentation for `LazyDoc`.\n\nThis module is an example of autogenerated docs by\nthe task provided.\n"
          },
          [
            {{:function, :func_without_doc, 0}, 31, ["func_without_doc()"],
             %{
               "en" =>
                 "Returns a message indicating a greeting.\n\n## Parameters\n\n- None\n## Description\nExecutes a print statement to display \"Hello world\"."
             }, %{}},
            {{:function, :hello, 0}, 26, ["hello()"],
             %{
               "en" =>
                 "Returns the atom :world.\n\n## Parameters\n\n- None\n## Description\nReturns a predefined atom value."
             }, %{}},
            {{:function, :my_func, 1}, 34, ["my_func(n)"],
             %{
               "en" =>
                 "Returns a description based on the input value.\n\n## Parameters\n\n- n - The input number to be described.\n## Description\n Generates a string representation of the input number."
             }, %{}},
            {{:function, :my_func_2, 1}, 9, ["my_func_2(n)"],
             %{
               "en" =>
                 "Returns the string representation of the input number.\n\n## Parameters\n\n- n - an integer value.\n\n## Description\n Returns a string indicating the value of n."
             }, %{}}
          ]}}
      ]

    assert docs_per_module == expected_result

    docs_per_module = LazyDoc.docs_per_module([LazyDoc.ExampleModule])

    expected_result =
      [
        {LazyDoc.ExampleModule,
         {:none,
          [
            {{:function, :bonjour, 0}, 26, ["bonjour()"], %{"en" => " It says Bonjour\n"}, %{}},
            {{:function, :fibs, 1}, 31, ["fibs(n)"], %{"en" => "  Hello there\n"}, %{}},
            {{:function, :fibs, 2}, 38, ["fibs(n, list)"], :none, %{}},
            {{:function, :greet, 0}, 22, ["greet()"], :hidden, %{}},
            {{:function, :hello, 1}, 5, ["hello(param)"], :none, %{}},
            {{:function, :hello_there, 1}, 16, ["hello_there(i)"], :none, %{}},
            {{:function, :hihi, 0}, 10, ["hihi()"], :none, %{}}
          ]}}
      ]

    assert docs_per_module == expected_result
  end

  test "filter undocumented docs" do
    {:ok, content} = File.read("test/support/example_module.ex")

    {:ok, ast, _comments} =
      Code.string_to_quoted_with_comments(content,
        literal_encoder: &{:ok, {:__block__, &2, [&1]}},
        token_metadata: true,
        unescape: false
      )

    name_module =
      LazyDoc.extract_names(ast)
      |> Enum.map(fn {:module, module_name, module_ast, code_mod, functions} ->
        {module_name |> Module.concat(), module_ast, code_mod,
         LazyDoc.join_code_from_clauses(functions)}
      end)
      |> Enum.find(fn {module_name, _module_ast, _code_mod, _functions} ->
        module_name == LazyDoc.ExampleModule
      end)

    docs_per_module =
      LazyDoc.docs_per_module([LazyDoc.ExampleModule])
      |> Enum.map(fn {module, {module_doc, func_docs}} ->
        {module, {module_doc, LazyDoc.group_docs_different_arities(func_docs)}}
      end)
      |> Enum.at(0)

    {_module, _module_ast, functions_to_document} =
      LazyDoc.filter_undocumented_functions(name_module, docs_per_module)

    assert functions_to_document |> Enum.map(fn {:function, {name, _code}} -> name end) == [
             :hihi,
             :hello,
             :hello_there
           ]
  end

  test "test docs_are_ok?" do
    assert TaskLazyDoc.docs_are_ok?(~s(@doc """\n pepe frog""")) == true
    assert TaskLazyDoc.docs_are_ok?("@doc \" queso curado \"") == true
    assert TaskLazyDoc.docs_are_ok?("pepe meme") == false
  end

  test "test docs_to_node" do
    {:ok, content} = File.read("test/support/example_module.ex")

    {:ok, ast, _comments} =
      Code.string_to_quoted_with_comments(content,
        literal_encoder: &{:ok, {:__block__, &2, [&1]}},
        token_metadata: true,
        unescape: false
      )

    docs = "@doc \"\"\"\npepe frog\n\"\"\""

    function_name = :hihi

    ## Expects always elixir @doc valid annotation
    new_ast = TaskLazyDoc.docs_to_node(docs, ast, function_name, [:LazyDoc, :ExampleModule])

    ## Check if the AST has @doc node before the :hihi node

    {:defmodule, _meta_mod, children} = new_ast

    [
      _aliases_node,
      [
        {{:__block__, _meta_block, [:do]}, {:__block__, _meta_inner_block, block_children}}
      ]
    ] = children

    index =
      Enum.find_index(block_children, fn elem ->
        match?({:def, _meta, [{:hihi, _meta_func, _params}, _func_block]}, elem)
      end)

    {:@, _meta_at,
     [
       {:doc, _meta_doc,
        [
          {:__block__, _meta_block, [message]}
        ]}
     ]} = Enum.at(block_children, index - 1)

    assert message == "pepe frog\n"
  end
end
