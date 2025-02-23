# LazyDoc

Lazy Doc is a project for those who are lazy af to document their code.

It is designed to detect undocumented functions, pass the function to an AI
provider which is a tuple of two elements `{GithubAi, :codestral}`.

## Roadmap

- Inspect the `defimpl` and `defprotocol` nodes.
- Customizable number of retries.
- Custom paramters to pass the model (max\_tokens, top\_p, temperature).

## Installation

``` elixir
def deps do
  [
    {:lazy_doc, "~> 0.3.0"}
  ]
end
```

## Configuration

`config/config.exs`

``` elixir
## alias of GithubAi above
config :lazy_doc, :provider, {GithubAi, :gpt_4o_mini}

## configure formatter.
config :lazy_doc, :line_length, 98

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

> Note: this limitation it is only in module names. So if the user have same
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
