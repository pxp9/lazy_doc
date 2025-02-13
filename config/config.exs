import Config

_ = """
      :codestral -> "Codestral-2501"
      :gpt_4o -> "gpt-4o"
      :gpt_4o_mini -> "gpt-4o-mini"

"""

config :lazy_doc, :provider, {:github, :gpt_4o_mini}
