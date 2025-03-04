defmodule LazyDoc.Provider do
  @moduledoc """

  ## Main functionality

  The module LazyDoc.Provider provides a standard interface for making requests to an external service and processing the responses.

  ## Description

  It defines a set of callbacks and functions that allow a user to request a prompt, retrieve documents from a response, and interact with models, enabling flexible integration with various providers that conform to this interface.
  """
  @callback request_prompt(
              prompt :: binary(),
              model :: binary(),
              token :: binary(),
              params :: keyword()
            ) ::
              {:ok, Req.Response.t()} | {:error, Exception.t()}

  @spec request_prompt(
          callback_module :: module(),
          prompt :: binary(),
          model :: binary(),
          token :: binary(),
          params :: keyword()
        ) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  @doc File.read!("lazy_doc/lazy_doc/provider/request_prompt.md")
  def request_prompt(callback_module, prompt, model, token, params \\ []),
    do: callback_module.request_prompt(prompt, model, token, params)

  @callback get_docs_from_response(response :: Req.Response.t()) :: binary()
  @spec get_docs_from_response(callback_module :: module(), response :: Req.Response.t()) ::
          binary()
  @doc File.read!("lazy_doc/lazy_doc/provider/get_docs_from_response.md")
  def get_docs_from_response(callback_module, response),
    do: callback_module.get_docs_from_response(response)

  @callback model(model :: atom()) :: binary()
  @spec model(callback_module :: module(), model :: atom()) :: binary()
  @doc File.read!("lazy_doc/lazy_doc/provider/model.md")
  def model(callback_module, model), do: callback_module.model(model)

  @callback check_parameters?(params :: keyword()) :: boolean()
  @spec check_parameters?(callback_module :: module(), params :: keyword()) :: boolean()
  @doc File.read!("lazy_doc/lazy_doc/provider/check_parameters?.md")
  def check_parameters?(callback_module, params), do: callback_module.check_parameters?(params)
end
