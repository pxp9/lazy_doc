# Implement your own provider

To implement your own provider and use it you just need to implement the
`LazyDoc.Provider` behavior for a module, and then you need to configure the
`:provider` option.

``` elixir
  config :lazy_doc, provider: {MyAwesomeProvider, :my_fancy_model, [max_tokens: 2048, top_p: 1, temperature: 1] = _keyword_list_with_options},
```

The tuple `:provider` has 3 elements:

- name of the module which implements `LazyDoc.Provider`
- the model to be used which is implemented in the given module.
- keyword list which are options implemented in the given module.
