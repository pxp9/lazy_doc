defmodule LazyDoc.Providers.GithubAi do
  @moduledoc """

   ## Main functionality

   The module LazyDoc.Providers.GithubAi provides a way of interacting with the Github AI API for prompt-based communication and response generation.

   ## Description

   It implements the behavior Provider, offering a standardized method to request and retrieve responses from AI models hosted on the Github AI platform. Key operations include sending prompts, constructing API requests, and processing responses.
  """
  @behaviour LazyDoc.Provider

  @github_ai_endpoint "https://models.github.ai/inference/chat/completions"

  ## TO_DO: make timeout,temperature, top_p and max_tokens customizable but with default values.
  ## TO_DO: implement retry with customizable number of retries if fails but with default value.
  @spec request_prompt(binary(), binary(), binary(), keyword()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()}
  @doc File.read!("lazy_doc/lazy_doc/providers/github_ai/request_prompt.md")
  def request_prompt(prompt, model, token, params \\ []) do
    req_query(prompt, model, token, params)
    |> Req.post()
  end

  @doc File.read!("lazy_doc/lazy_doc/providers/github_ai/req_query.md")
  def req_query(prompt, model, token, params \\ []) do
    temperature = Keyword.get(params, :temperature, 1)
    top_p = Keyword.get(params, :top_p, 1)
    max_tokens = Keyword.get(params, :max_tokens, 2048)

    max_retries = Application.get_env(:lazy_doc, :max_retries, 1)
    receive_timeout = Application.get_env(:lazy_doc, :receive_timeout, 15_000)

    body = %{
      max_tokens: max_tokens,
      messages: [%{"role" => "system", "content" => ""}, %{"role" => "user", "content" => prompt}],
      model: "#{model}",
      temperature: temperature,
      top_p: top_p
    }

    Req.new(
      base_url: @github_ai_endpoint,
      json: body,
      receive_timeout: receive_timeout,
      max_retries: max_retries
    )
    |> Req.Request.put_header("Accept", "application/json")
    |> Req.Request.put_header("Content-Type", "application/json;charset=UTF-8")
    |> Req.Request.put_header("Authorization", "Bearer #{token}")
    |> Req.Steps.encode_body()
  end

  ## TO_DO: we should review if for each model in Github you have the same response format in the body.
  ## Maybe this premise is not true and it will require changes.
  @spec get_docs_from_response(Req.Response.t()) :: binary()
  @doc File.read!("lazy_doc/lazy_doc/providers/github_ai/get_docs_from_response.md")
  def get_docs_from_response(%Req.Response{body: body} = _response) do
    ## Take always first choice
    message = Enum.at(body["choices"], 0)["message"]["content"]
    message
  end

  @spec model(atom()) :: binary()
  @doc File.read!("lazy_doc/lazy_doc/providers/github_ai/model.md")
  def model(model) do
    case model do
      :codestral -> "Codestral-2501"
      :gpt_4o -> "gpt-4o"
      :gpt_4o_mini -> "gpt-4o-mini"
    end
  end

  @spec check_parameters?(params :: keyword()) :: boolean()
  @doc File.read!("lazy_doc/lazy_doc/providers/github_ai/check_parameters?.md")
  def check_parameters?(params) do
    valid_params = [:max_tokens, :top_p, :temperature]
    Enum.map(params, fn {key, _value} -> key in valid_params end) |> Enum.all?()
  end
end
