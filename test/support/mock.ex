defmodule Anthropix.Mock do
  alias Plug.Conn.Status
  import Plug.Conn

  @mocks %{
    :messages => %{
      "content" => [
        %{
          "type" => "text",
          "text" => "Here's a haiku about the color of the sky:\\n\\nBlue canvas stretched wide,\\nClouds drift lazily across,\\nSky's endless expanse."
        }
      ],
      "id" => "msg_test",
      "model" => "claude-3-sonnet-20240229",
      "role" => "assistant",
      "stop_reason" => "end_turn",
      "stop_sequence" => nil,
      "type" => "message",
      "usage" => %{"input_tokens" => 18, "output_tokens" => 36}
    },

    :messages_tools => %{
      "content" => [
        %{"text" => "Okay, let me check the weather for London:", "type" => "text"},
        %{
          "id" => "toolu_01C8aPF8bZPusgu3LvVAf4Mo",
          "input" => %{"location" => "London"},
          "name" => "get_weather",
          "type" => "tool_use"
        }
      ],
      "id" => "msg_01THGxy3R57vpDPKmqPmcALZ",
      "model" => "claude-3-haiku-20240307",
      "role" => "assistant",
      "stop_reason" => "tool_use",
      "stop_sequence" => nil,
      "type" => "message",
      "usage" => %{
        "cache_creation_input_tokens" => 0,
        "cache_read_input_tokens" => 0,
        "input_tokens" => 348,
        "output_tokens" => 65
      }
    },

    :messages_thinking => %{
      "content" => [
        %{
          "signature" => "EuYBCkQYAiJAOlUl3hxNSxKkGObU7125QRAymecmp7a1cTXpmwNv6Jx8G022M+qnNlx7o9Mq03cM2P4f/n+RN5hfk2v16rNWihIMUTgK+W9in5eBdxJMGgyeHz2pYd8PU8rXNXsiME+yUYUlBBqZ5dtT2FFOjqqSDOxd4EWhl3X12Xa135wNi+lqfr/X0vsMxvr5YUxMvypQupR16mWkWuOP2QyM7gTwl63VdYYKPjlQlha3kCLqjNn4Ncm/g8wJ2QpJcU+lOMx5Zddi/n4oT+pW5yxMJW7pzcZWEmlqZAH3K4qJ6/81gMM=",
          "thinking" => "I need to count the number of letter \"R\"s in the word \"strawberry\".\n\nLet me spell it out: s-t-r-a-w-b-e-r-r-y\n\nNow I'll count the R's:\n1. First \"r\" after \"t\"\n2. Second \"r\" after \"e\"\n3. Third \"r\" before \"y\"\n\nSo there are 3 R's in the word \"strawberry\".",
          "type" => "thinking"
        },
        %{"text" => "There are 3 R's in the word \"strawberry\".", "type" => "text"}
      ],
      "id" => "msg_01SWbnGuMmnusNsWSEoArzxZ",
      "model" => "claude-3-7-sonnet-20250219",
      "role" => "assistant",
      "stop_reason" => "end_turn",
      "stop_sequence" => nil,
      "type" => "message",
      "usage" => %{
        "cache_creation_input_tokens" => 0,
        "cache_read_input_tokens" => 0,
        "input_tokens" => 45,
        "output_tokens" => 129
      }
    },

    :batch_list => %{
      "data" => [
        %{
          "cancel_initiated_at" => nil,
          "created_at" => "2024-10-14T17:18:08.256576+00:00",
          "ended_at" => "2024-10-14T17:18:35.428981+00:00",
          "expires_at" => "2024-10-15T17:18:08.256576+00:00",
          "id" => "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R",
          "processing_status" => "ended",
          "request_counts" => %{
            "canceled" => 0,
            "errored" => 0,
            "expired" => 0,
            "processing" => 0,
            "succeeded" => 2
          },
          "results_url" => "https://api.anthropic.com/v1/messages/batches/msgbatch_01DJuZbTFXpGRhqTdqFH1P2R/results",
          "type" => "message_batch"
        }
      ],
      "first_id" => "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R",
      "has_more" => false,
      "last_id" => "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R"
    },

    :batch_create => %{
      "cancel_initiated_at" => nil,
      "created_at" => "2024-10-14T17:18:08.256576+00:00",
      "ended_at" => nil,
      "expires_at" => "2024-10-15T17:18:08.256576+00:00",
      "id" => "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R",
      "processing_status" => "in_progress",
      "request_counts" => %{
        "canceled" => 0,
        "errored" => 0,
        "expired" => 0,
        "processing" => 2,
        "succeeded" => 0
      },
      "results_url" => nil,
      "type" => "message_batch"
    },

    :batch_show => %{
      "cancel_initiated_at" => nil,
      "created_at" => "2024-10-14T17:18:08.256576+00:00",
      "ended_at" => "2024-10-14T17:18:35.428981+00:00",
      "expires_at" => "2024-10-15T17:18:08.256576+00:00",
      "id" => "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R",
      "processing_status" => "ended",
      "request_counts" => %{
        "canceled" => 0,
        "errored" => 0,
        "expired" => 0,
        "processing" => 0,
        "succeeded" => 2
      },
      "results_url" => "https://api.anthropic.com/v1/messages/batches/msgbatch_01DJuZbTFXpGRhqTdqFH1P2R/results",
      "type" => "message_batch"
    },

    :batch_results => "{\"custom_id\":\"foo\",\"result\":{\"type\":\"succeeded\",\"message\":{\"id\":\"msg_01Dumy2zp6ymYzsHjJ5xEpdw\",\"type\":\"message\",\"role\":\"assistant\",\"model\":\"claude-3-haiku-20240307\",\"content\":[{\"type\":\"text\",\"text\":\"The sky appears blue for a few key reasons:\\n\\n1. Scattering of sunlight by the atmosphere - As sunlight passes through the Earth's atmosphere, the shorter wavelengths of light (the blues and violets) get scattered more by the gas molecules in the air than the longer wavelengths (the reds and oranges). This selective scattering of the blue wavelengths is known as Rayleigh scattering, named after the physicist John Rayleigh.\\n\\n2. Composition of the atmosphere - The Earth's atmosphere is composed mainly of nitrogen and oxygen molecules. These molecules are just the right size to efficiently scatter the shorter blue wavelengths of sunlight, making the sky appear blue.\\n\\n3. Perception by the human eye - The human eye is more sensitive to the blue wavelengths, so the scattered blue light appears more dominant and vibrant to our eyes compared to the other scattered wavelengths.\\n\\nSo in summary, it is the physical process of Rayleigh scattering combined with the composition of the atmosphere and the human visual perception that makes the sky appear blue. The effect is most pronounced during the day when the sun's light is passing through more of the atmosphere.\"}],\"stop_reason\":\"end_turn\",\"stop_sequence\":null,\"usage\":{\"input_tokens\":13,\"cache_creation_input_tokens\":0,\"cache_read_input_tokens\":0,\"output_tokens\":259}}}}\n{\"custom_id\":\"bar\",\"result\":{\"type\":\"succeeded\",\"message\":{\"id\":\"msg_01BFAMXhx5nZEbbKyVqdzvQ1\",\"type\":\"message\",\"role\":\"assistant\",\"model\":\"claude-3-haiku-20240307\",\"content\":[{\"type\":\"text\",\"text\":\"There are a few reasons why the sea appears blue in color:\\n\\n1. Light Scattering - The main reason is the way light interacts with water molecules. When sunlight hits the water, the shorter wavelengths of light (blues and violets) get scattered more easily by the water molecules. This preferential scattering of blue light is known as the Rayleigh scattering effect, and it's the same phenomenon that makes the sky appear blue.\\n\\n2. Water Absorption - Water absorbs more of the longer wavelengths of the visible spectrum (reds and yellows) compared to the shorter blue wavelengths. This selective absorption contributes to the overall blue appearance.\\n\\n3. Pigments - Certain pigments and dissolved organic matter in ocean water can also influence the perceived color. Phytoplankton and other dissolved organic compounds can give the water a greenish or brownish tint in some areas.\\n\\n4. Depth and Clarity - The deeper and clearer the water, the more pronounced the blue color appears. Shallow waters or waters with a lot of suspended sediment tend to appear more green or turquoise.\\n\\nSo in summary, it is primarily the way water interacts with and absorbs different wavelengths of sunlight that gives the ocean its characteristic blue hue. The precise shade can vary depending on local conditions and composition of the water.\"}],\"stop_reason\":\"end_turn\",\"stop_sequence\":null,\"usage\":{\"input_tokens\":13,\"cache_creation_input_tokens\":0,\"cache_read_input_tokens\":0,\"output_tokens\":298}}}}"
  }

  @stream_mocks %{
    messages: [
      %{"type" => "message_start", "message" => %{
        "content" => [],
        "id" => "msg_01AgC6AM5riFWbgj1ZoSgD1b",
        "model" => "claude-3-sonnet-20240229",
        "role" => "assistant",
        "stop_reason" => nil,
        "stop_sequence" => nil,
        "type" => "message",
        "usage" => %{"input_tokens" => 18, "output_tokens" => 1}
      }},
      %{"type" => "content_block_start", "index" => 0, "content_block" => %{"text" => "", "type" => "text"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => "Here", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => "'s", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " a", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " ha", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => "iku", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " about", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " the", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " color", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " of", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " the", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " sky", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => ":", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => "\n\nAzure", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " can", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => "opy", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => "\nStret", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => "ching", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " vast", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " above", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " the", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " earth", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => "\nSky", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => "'s", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " bound", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => "less", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " beauty", "type" => "text_delta"}},
      %{"type" => "content_block_stop", "index" => 0},
      %{"type" => "message_delta", "delta" => %{"stop_reason" => "end_turn", "stop_sequence" => nil}, "usage" => %{"output_tokens" => 34}},
      %{"type" => "message_stop"}
    ],

    messages_tools: [
      %{"type" => "message_start", "message" => %{
        "content" => [],
        "id" => "msg_017cEgug4oBcJZ9BBpB4iFuS",
        "model" => "claude-3-haiku-20240307",
        "role" => "assistant",
        "stop_reason" => nil,
        "stop_sequence" => nil,
        "type" => "message",
        "usage" => %{"cache_creation_input_tokens" => 0, "cache_read_input_tokens" => 0, "input_tokens" => 348, "output_tokens" => 4}
      }},
      %{"type" => "content_block_start", "index" => 0, "content_block" => %{"text" => "", "type" => "text"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => "Here is the weather", "type" => "text_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"text" => " for London:", "type" => "text_delta"}},
      %{"type" => "content_block_stop", "index" => 0},
      %{"type" => "content_block_start", "index" => 1, "content_block" => %{
        "id" => "toolu_01HkwGv3jQLx1fGJV8qfskQZ",
        "input" => %{},
        "name" => "get_weather",
        "type" => "tool_use"
      }},
      %{"type" => "content_block_delta", "index" => 1, "delta" => %{"partial_json" => "", "type" => "input_json_delta"}},
      %{"type" => "content_block_delta", "index" => 1, "delta" => %{"partial_json" => "{\"location\"", "type" => "input_json_delta"}},
      %{"type" => "content_block_delta", "index" => 1, "delta" => %{"partial_json" => ": \"Lond", "type" => "input_json_delta"}},
      %{"type" => "content_block_delta", "index" => 1, "delta" => %{"partial_json" => "on\"}", "type" => "input_json_delta"}},
      %{"type" => "content_block_stop", "index" => 1},
      %{"type" => "message_delta", "delta" => %{"stop_reason" => "tool_use", "stop_sequence" => nil}, "usage" => %{"output_tokens" => 61}},
      %{"type" => "message_stop"}
    ],

    messages_thinking: [
      %{"type" => "message_start", "message" => %{
        "content" => [],
        "id" => "msg_01GagrVPbxkxRgAPP8J74FyM",
        "model" => "claude-3-7-sonnet-20250219",
        "role" => "assistant",
        "stop_reason" => nil,
        "stop_sequence" => nil,
        "type" => "message",
        "usage" => %{"cache_creation_input_tokens" => 0, "cache_read_input_tokens" => 0, "input_tokens" => 45, "output_tokens" => 8}
      }},
      %{"type" => "content_block_start", "index" => 0, "content_block" => %{"signature" => "", "thinking" => "", "type" => "thinking"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"thinking" => "Let me count the number of letter", "type" => "thinking_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"thinking" => " 'r's in the word \"straw", "type" => "thinking_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"thinking" => "berry\".\n\nThe word \"strawberry\" is", "type" => "thinking_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"thinking" => " spelled: s-t-r-a-w-b-", "type" => "thinking_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"thinking" => "e-r-r-y\n\nI see", "type" => "thinking_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"thinking" => " the letter 'r' in the", "type" => "thinking_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"thinking" => " following positions:\n- 3rd position:", "type" => "thinking_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"thinking" => " \"str\"\n- 8th position: \"straw", "type" => "thinking_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"thinking" => "ber\"\n- 9th position: \"", "type" => "thinking_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"thinking" => "strawberr\"\n\nSo there are 3", "type" => "thinking_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"thinking" => " r's in \"strawberry\".", "type" => "thinking_delta"}},
      %{"type" => "content_block_delta", "index" => 0, "delta" => %{"signature" => "EuYBCkQYAiJApKyEzxcNGnvxbktXpkSeaaQRqSPonVuNTbvhWOPAeFQ0HKRGlKrVgE4NQi+0zTTlEdnbUDUks8lzMUK2k/MSIhIMDNNdtCKVjAzRaEGyGgwzqFDl27GgpV9ig1MiMIpYiv8Xn3ICpy/MyZFzRgQ1WrV/rw4iQfpk5G23nCLNlOoQyUFMl16caZiHehF1GCpQZyta9Vp0y2rWgmYrYyubCQJ61duztX2V3ahGVipRTodlmmRSzKeCNgI2nCFYnC9lUfk1o8MXGwUBmrBo6fzMMjpGbA0/2bekmUJq/mIL2kU=", "type" => "signature_delta"}},
      %{"type" => "content_block_stop", "index" => 0},
      %{"type" => "content_block_start", "index" => 1, "content_block" => %{"text" => "", "type" => "text"}},
      %{"type" => "content_block_delta", "index" => 1, "delta" => %{"text" => "There are 3 r's in the word \"strawberry\".", "type" => "text_delta"}},
      %{"type" => "content_block_stop", "index" => 1},
      %{"type" => "message_delta", "delta" => %{"stop_reason" => "end_turn", "stop_sequence" => nil}, "usage" => %{"output_tokens" => 134}},
      %{"type" => "message_stop"}
    ]
  }

  @spec client(function()) :: Anthropix.client()
  def client(plug) when is_function(plug, 1) do
    struct(Anthropix, req: Req.new(plug: plug))
  end

  @spec respond(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def respond(conn, :batch_results) do
    conn
    |> put_resp_header("content-disposition", "attachment; filename=\"results.jsonl\"")
    |> send_resp(200, @mocks[:batch_results])
  end

  def respond(conn, name) when is_atom(name) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(@mocks[name]))
  end

  def respond(conn, status) when is_number(status) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status, Jason.encode!(%{
      error: %{
        type: Status.reason_atom(status),
        message: Status.reason_phrase(status),
      }
    }))
  end

  def respond(conn, {:agent, :messages}) do
    # Manually run through the json parser plug
    opts = Plug.Parsers.init(parsers: [:json], json_decoder: Jason)
    conn = Plug.Parsers.call(conn, opts)

    m = conn.body_params["messages"]
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(@mocks[{:agent, :messages, length(m)}]))
  end

  @spec stream(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def stream(conn, name) when is_atom(name) do
    Enum.reduce(@stream_mocks[name], send_chunked(conn, 200), fn chunk, conn ->
      {:ok, conn} = chunk(conn, to_sse_event(chunk))
      conn
    end)
  end

  defp to_sse_event(%{"type" => event} = data) do
    """
    event: #{event}
    data: #{Jason.encode!(data)}\n\n
    """
  end

end
