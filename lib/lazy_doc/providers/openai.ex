defmodule LazyDoc.Providers.OpenAi do
  @moduledoc """

  The module LazyDoc.Providers.OpenAi provides an interface for interacting with the OpenAI API, facilitating access to AI-powered code generation and completion functionalities.

  ## Description

  https://platform.openai.com/docs/api-reference/chat/create

  This module defines a provider behavior for the LazyDoc library, specifically tailored for making requests to the OpenAI API. It allows users to send prompts to the API and retrieve generated responses based on specified models and parameters. The functionality includes constructing requests with necessary headers and parameters, handling the responses received from the API, and providing a way to validate the parameters used in the requests. Additionally, it supports the specification of different AI models that can be utilized for generating completions, making this module a flexible tool for leveraging AI in documentation and development processes.
  """
  @behaviour LazyDoc.Provider

  @openai_endpoint "https://api.openai.com/v1/chat/completions"
  @spec request_prompt(binary(), binary(), binary(), keyword()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()}
  @doc File.read!("priv/lazy_doc/lazy_doc/providers/openai/request_prompt.md")
  def request_prompt(prompt, model, token, params \\ []) do
    req_query(prompt, model, token, params)
    |> Req.post()
  end

  @doc File.read!("priv/lazy_doc/lazy_doc/providers/openai/req_query.md")
  def req_query(prompt, model, token, params \\ []) do
    temperature = Keyword.get(params, :temperature, 1)
    top_p = Keyword.get(params, :top_p, 1)
    max_completion_tokens = Keyword.get(params, :max_completion_tokens, 2048)

    max_retries = Application.get_env(:lazy_doc, :max_retries, 1)
    receive_timeout = Application.get_env(:lazy_doc, :receive_timeout, 15_000)

    ## Maybe we need to fix role => system for old models.
    body = %{
      max_completion_tokens: max_completion_tokens,
      messages: [
        %{"role" => "developer", "content" => ""},
        %{"role" => "user", "content" => prompt}
      ],
      model: "#{model}",
      temperature: temperature,
      top_p: top_p
    }

    Req.new(
      base_url: @openai_endpoint,
      json: body,
      receive_timeout: receive_timeout,
      max_retries: max_retries
    )
    |> Req.Request.put_header("Accept", "application/json")
    |> Req.Request.put_header("Content-Type", "application/json;charset=UTF-8")
    |> Req.Request.put_header("Authorization", "Bearer #{token}")
    |> Req.Steps.encode_body()
  end

  @spec get_docs_from_response(Req.Response.t()) :: binary()
  @doc File.read!("priv/lazy_doc/lazy_doc/providers/openai/get_docs_from_response.md")
  def get_docs_from_response(%Req.Response{body: body} = _response) do
    ## Take always first choice
    message = Enum.at(body["choices"], 0)["message"]["content"]
    message
  end

  @spec model(atom()) :: binary()
  @doc File.read!("priv/lazy_doc/lazy_doc/providers/openai/model.md")
  def model(model) do
    case model do
      :gpt_4o -> "gpt-4o"
      :gpt_4o_mini -> "gpt-4o-mini"
      :o1 -> "o1"
    end
  end

  @spec check_parameters?(params :: keyword()) :: boolean()
  @doc File.read!("priv/lazy_doc/lazy_doc/providers/openai/check_parameters?.md")
  def check_parameters?(params) do
    valid_params = [:max_completion_tokens, :top_p, :temperature]
    Enum.map(params, fn {key, _value} -> key in valid_params end) |> Enum.all?()
  end
end
