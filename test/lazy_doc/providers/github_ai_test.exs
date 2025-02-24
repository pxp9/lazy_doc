defmodule LazyDoc.Providers.GithubAiTest do
  use ExUnit.Case

  alias LazyDoc.Provider
  alias LazyDoc.Providers.GithubAi

  test "test success calling the provider" do
    model = Provider.model(GithubAi, :gpt_4o_mini)

    assert model == "gpt-4o-mini"
    token = "TOKEN"
    prompt = "some prompt"

    Req.Test.stub(GithubAi, fn conn ->
      conn
      |> Plug.Conn.put_status(201)
      |> Req.Test.json(example_response(prompt))
    end)

    req = GithubAi.req_query(prompt, model, token)
    req = Req.merge(req, plug: {Req.Test, GithubAi})

    assert {:ok, resp} = req |> Req.post()

    docs = Provider.get_docs_from_response(GithubAi, resp)

    assert ~s(@doc """\n #{prompt} \n""") == docs
  end

  # Works with Req > 0.5

  # test "test unsueccessful call to provider" do
  #   model = Provider.model(GithubAi, :gpt_4o_mini)

  #   assert model == "gpt-4o-mini"
  #   token = "TOKEN"
  #   prompt = "some prompt"

  #   Req.Test.stub(GithubAi, fn conn ->
  #     conn
  #     |> Req.Test.transport_error(:timeout)
  #   end)

  #   req = GithubAi.req_query(prompt, model, token)
  #   req = Req.merge(req, plug: {Req.Test, GithubAi})

  #   assert {:error, %Req.TransportError{reason: :timeout}} == req |> Req.post() |> dbg
  # end

  def example_response(prompt) do
    %{
      "choices" => [
        %{
          "content_filter_results" => %{
            "hate" => %{"filtered" => false, "severity" => "safe"},
            "protected_material_code" => %{
              "detected" => false,
              "filtered" => false
            },
            "protected_material_text" => %{
              "detected" => false,
              "filtered" => false
            },
            "self_harm" => %{"filtered" => false, "severity" => "safe"},
            "sexual" => %{"filtered" => false, "severity" => "safe"},
            "violence" => %{"filtered" => false, "severity" => "safe"}
          },
          "finish_reason" => "stop",
          "index" => 0,
          "logprobs" => nil,
          "message" => %{
            "content" => "@doc \"\"\"\n #{prompt} \n\"\"\"",
            "refusal" => nil,
            "role" => "assistant"
          }
        }
      ],
      "created" => 1_739_901_560,
      "id" => "chatcmpl-B2MAKt4UYca7IXRKsxRotMMkrLZJs",
      "model" => "gpt-4o-mini-2024-07-18",
      "object" => "chat.completion",
      "prompt_filter_results" => [
        %{
          "content_filter_results" => %{
            "hate" => %{"filtered" => false, "severity" => "safe"},
            "jailbreak" => %{"detected" => false, "filtered" => false},
            "self_harm" => %{"filtered" => false, "severity" => "safe"},
            "sexual" => %{"filtered" => false, "severity" => "safe"},
            "violence" => %{"filtered" => false, "severity" => "safe"}
          },
          "prompt_index" => 0
        }
      ],
      "system_fingerprint" => "fp_b045b4af17",
      "usage" => %{
        "completion_tokens" => 9,
        "completion_tokens_details" => %{
          "accepted_prediction_tokens" => 0,
          "audio_tokens" => 0,
          "reasoning_tokens" => 0,
          "rejected_prediction_tokens" => 0
        },
        "prompt_tokens" => 12,
        "prompt_tokens_details" => %{"audio_tokens" => 0, "cached_tokens" => 0},
        "total_tokens" => 21
      }
    }
  end
end
