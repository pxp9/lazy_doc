# LazyDoc

Lazy Doc is a project for those who are lazy af to document their code.

It is designed to detect undocumented functions, pass the function to an AI
provider which is a tuple of two elements `{:github, :codestral}`.

## Roadmap

- Make AI docs for modules as well, `@module_doc`.
- Inspect the `defimpl` and `defprotocol` nodes.
- Make AI providers more extensible (define a protocol of what an AI provider
  should do).
  - request callback
  - response callback (basically get a plain string with the docs so the task
    can parse it as AST).
- Make some tests.

## Installation

``` elixir
def deps do
  [
    {:lazy_doc, "~> 0.1.0"}
  ]
end
```

## Configuration

`config/config.exs`

``` elixir
config :lazy_doc, :provider, {:github, :gpt_4o_mini}

config :lazy_doc,
       :custom_function_prompt,
       "You should describe the parameters based on the spec given and give a small description of the following function.\n\nPlease do it in the following format given as an example, important do not return the header of the function, do not return a explanation of the function, your output must be only the docs in the following format.\n\n@doc \"\"\"\n\nParameters\n\ntransaction_id - foreign key of the Transactions table.\nDescription\n Performs a search in the database\n\nReturns\n the Transaction corresponding to transaction_id\n\n\"\"\"\n\nFunction to document:\n"

config :lazy_doc, :path_wildcard, "lib/**/*.ex"
```

`config/runtime.exs`

``` elixir
config :lazy_doc, :token, System.get_env("API_TOKEN")
```

`.env`

``` bash
API_TOKEN="YOUR AWESOME TOKEN"
```
