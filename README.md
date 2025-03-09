# LazyDoc

<p align='center'>
<img alt="Static Badge" src="https://img.shields.io/badge/GitHub%20Pages-222222?style=for-the-badge&logo=github&logoColor=white&label=Read%20the%20article!&link=https%3A%2F%2Fpxp9.github.io%2Flazy-doc">

<img alt="Static Badge" src="https://img.shields.io/badge/elixir-%25234B275F.svg?style=for-the-badge&logo=elixir&logoColor=white&label=Read%20the%20post!&color=purple&link=https%3A%2F%2Felixirforum.com%2Ft%2Flazydoc-detect-undocumented-functions-and-pass-the-function-to-an-ai-provider-to-document-it%2F69818">
</p>

Lazy Doc is a project for those who are lazy af to document their code.

It is designed to detect undocumented functions, pass the function to an AI
provider which is a tuple of two elements `{GithubAi, :codestral}`.

## Installation

``` elixir
def deps do
  [
    {:lazy_doc, "~> 0.5.3"}
  ]
end
```

## Configuration

`config/config.exs`

``` elixir
## alias of GithubAi above
import Config
alias LazyDoc.Providers.GithubAi
## configure formatter.
config :lazy_doc,
  patterns: [
   ~r"^lib/[a-zA-Z_]+(?:/[a-zA-Z_]+)*/[a-zA-Z_]+\.ex$",
  ],
  max_retries: 3,
  receive_timeout: 15_000,
  file_formatter: ".formatter.exs",
  provider: {GithubAi, :gpt_4o_mini, [max_tokens: 2048, top_p: 1, temperature: 1]},
  custom_function_prompt:
    ~s(You should describe the parameters based on the spec given and give a small description of the following function.\n\nPlease do it in the following format given as an example, important do not return the header of the function, do not return a explanation of the function, your output must be only the docs in the following format.\n\n@doc """\n\n## Parameters\n\n- transaction_id - foreign key of the Transactions table.\n## Description\n Performs a search in the database\n\n## Returns\n the Transaction corresponding to transaction_id\n\n"""\n\nFunction to document:\n),
  custom_module_prompt:
    ~s(You should describe what this module does based on the code given.\n\n Please do it in the following format given as an example, important do not return the code of the module, your output must be only the docs in the following format.\n\n@moduledoc """\n\nThe module GithubAi provides a way of communicating with Github AI API \(describes the main functionality of the module\).\n\n## Description\n\nIt implements the behavior Provider a standard way to use a provider in LazyDoc.\(gives a detailed description of what the module does\)\n"""\n\nModule to document:\n)
```

`config/runtime.exs`

``` elixir
config :lazy_doc, :token, System.get_env("API_TOKEN")
```

`.env`

``` bash
API_TOKEN="YOUR AWESOME TOKEN"
```

### Available Providers implemented by LazyDoc

#### Github AI API

You can find the models you can use in this API [here](https://github.com/marketplace/models)

You can find the list of models implemented [here](https://github.com/pxp9/lazy_doc/blob/main/lib/lazy_doc/providers/github_ai.ex#L65)

You can generate a token for this API [here](https://github.com/settings/tokens), it is just a regular Github token.

More models need to be implemented in the future for this API.

#### Implement your own provider

To implement your own provider and use it you just need to implement the `LazyDoc.Provider` behavior for a module,
and then you need to configure the `:provider` option.

```elixir
  config :lazy_doc, provider: {MyAwesomeProvider, :my_fancy_model, [max_tokens: 2048, top_p: 1, temperature: 1] = _keyword_list_with_options},
```
The tuple `:provider` has 3 elements:

- name of the module which implements `LazyDoc.Provider`
- the model to be used which is implemented in the given module.
- keyword list which are options implemented in the given module.

## How to run it ?

From the root of the elixir project once installed and configured.

``` bash
mix lazy_doc
```

I would recommend to run a `mix format` after just in case.

If you want, you can add a simple check to see what needs to be documented in
your project. This is good for CI.

``` bash
mix lazy_doc.check
```

## Known limitations that wont be fixed.

### Module names in the same file must be different.

If the user creates an inner module with the same name as the parent module
`lazy_doc`, it wont work properly because they have the same `:__aliases__` AST
node.

> [!WARNING]
> This limitation it is only in module names. So if the user have same
> names of functions in different modules or in the same module, it will work.

``` elixir

defmodule Hello do

  defmodule Hello do

  end

end
```

produces the following AST

``` elixir
{:defmodule, [line: 1],
 [
## This is why it does not work [:Hello] 
   {:__aliases__, [line: 1], [:Hello]},
   [
     do: {:defmodule, [line: 3],
      [
        {:__aliases__, [line: 3],
## This is why it does not work [:Hello] 
         [:Hello]},
        [do: {:__block__, [], []}]
      ]}
   ]
 ]}
```

## Roadmap

- [X] Make AI docs for functions `@doc`.
- [X] Simple check if the response is in `@doc` format.
- [X] Make AI providers more extensible (define a behavior, what an AI provider
  should do ?).
- [X] Custom path wildcard (limits the action of `lazy_doc`)
- [X] Make some unit tests.
- [X] Improve the default prompt to generate markdown syntax.
- [X] Fix inner module detection (creates scopes for inner modules and builds
  the full name of the inner module).
- [X] Make a task or an arg in the current task to check if the functions are
  documented. (allows CI usage)
- [X] File is written to file according to Elixir formatter.
- [X] Make AI docs for modules as well, `@moduledoc`.
- [X] Custom prompts for function and module.
- [ ] Simple check if the response is in `@moduledoc` format.
- [X] Customizable number of retries.
- [X] Custom paramters to pass the provider (max\_tokens, top\_p, temperature).
- [X] Check if custom paramters are valid for that provider.
- [ ] Inspect the `defimpl` and `defprotocol` nodes.
- [ ] Make `@moduledoc` documentation take data from the Modules is related the
  given module.
- [ ] Spec mode: Detect if a function does not have any `@specs` and try to
  generate their specs.
- [X] Make an option `external_docs` to do `@doc
  File.read!("file_gen_by_lazy_doc.md")`, this will prevent code redability
  issues, it will create a folder where all the docs is generated.
- [X] Make a `mix lazy_doc.clean` task that will allow to clear all the docs for
  updating to new docs.
