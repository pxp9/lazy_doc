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
