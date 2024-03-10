defmodule Anthropix.MockServer do
  use Plug.Router

  @mocks %{
    messages: """
    {
      "content": [
        {
          "type": "text",
          "text": "Here's a haiku about the color of the sky:\\n\\nBlue canvas stretched wide,\\nClouds drift lazily across,\\nSky's endless expanse."
        }
      ],
      "id": "msg_test",
      "model": "claude-3-sonnet-20240229",
      "role": "assistant",
      "stop_reason": "end_turn",
      "stop_sequence": null,
      "type": "message",
      "usage": {"input_tokens": 18, "output_tokens": 36}
    }
    """
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
    ]
  }

  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  post "/messages", do: handle_request(conn, :messages)

  defp handle_request(conn, name) do
    case conn.body_params do
      %{"model" => "not-found"} -> respond(conn, 404)
      %{"stream" => true} -> stream(conn, name)
      _ -> respond(conn, name)
    end
  end

  defp respond(conn, name) when is_atom(name) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, @mocks[name])
  end

  defp respond(conn, status) when is_number(status) do
    send_resp(conn, status, "")
  end

  defp stream(conn, name) do
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
