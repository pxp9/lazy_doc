import Config
alias LazyDoc.Providers.GithubAi

_ = """
      :codestral -> "Codestral-2501"
      :gpt_4o -> "gpt-4o"
      :gpt_4o_mini -> "gpt-4o-mini"

"""

config :lazy_doc, :provider, {GithubAi, :gpt_4o_mini}

config :lazy_doc, :line_length, 98

config :lazy_doc,
       :custom_function_prompt,
       ~s(You should describe the parameters based on the spec given and give a small description of the following function.\n\nPlease do it in the following format given as an example, important do not return the header of the function, do not return a explanation of the function, your output must be only the docs in the following format.\n\n@doc """\n\n## Parameters\n\n- transaction_id - foreign key of the Transactions table.\n## Description\n Performs a search in the database\n\n## Returns\n the Transaction corresponding to transaction_id\n\n"""\n\nFunction to document:\n)

config :lazy_doc, :path_wildcard, "lib/**/*.ex"
