defmodule LazyDoc.Provider do
  @callback request_prompt(prompt :: binary(), model :: binary(), token :: binary()) ::
              {:ok, Req.Response.t()} | {:error, Exception.t()}

  @spec request_prompt(
          callback_module :: module(),
          prompt :: binary(),
          model :: binary(),
          token :: binary()
        ) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  @doc """

  Parameters

  callback_module - a module that handles the request for the prompt.
  prompt - the text prompt to be processed.
  model - the model to be used for generating the response to the prompt.
  token - authorization token to access the service.

  Description
   Initiates a request to generate a response based on the provided prompt using the specified model and token.

  Returns
   the response generated by the callback_module for the given prompt.

  """
  def request_prompt(callback_module, prompt, model, token),
    do: callback_module.request_prompt(prompt, model, token)

  @callback get_docs_from_response(response :: Req.Response.t()) :: binary()
  @spec get_docs_from_response(callback_module :: module(), response :: Req.Response.t()) ::
          binary()
  @doc """

  Parameters

  callback_module - a module that implements the method to retrieve documents.
  response - data received from an external source that needs to be processed.

  Description
   Calls the method get_docs_from_response on the provided callback_module with the given response to retrieve documents.

  Returns
   the documents extracted from the response.

  """
  def get_docs_from_response(callback_module, response),
    do: callback_module.get_docs_from_response(response)

  @callback model(model :: atom()) :: binary()
  @spec model(callback_module :: module(), model :: atom()) :: binary()
  @doc """
    
  Parameters

  callback_module - a module that contains the model function to be invoked.
  model - the model that needs to be passed to the callback module's model function.
  Description
   Invokes the model function of the provided callback module with the specified model.

  Returns
   the result from the callback module's model function.
    
  """
  def model(callback_module, model), do: callback_module.model(model)
end
