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

    {:agent, :messages, 1} => %{
      "content" => [
        %{
          "text" => "Here's how I'll find the current stock price for General Motors, yo:\n\n<function_calls>\n<invoke>\n<tool_name>get_ticker_symbol</tool_name>\n<parameters>\n<company_name>General Motors</company_name>\n</parameters>\n</invoke>\n",
          "type" => "text"
        }
      ],
      "id" => "msg_01FJNLQSEpck6s1cimMJ9Ru1",
      "model" => "claude-3-sonnet-20240229",
      "role" => "assistant",
      "stop_reason" => "stop_sequence",
      "stop_sequence" => "</function_calls>",
      "type" => "message",
      "usage" => %{"input_tokens" => 333, "output_tokens" => 73}
    },

    {:agent, :messages, 3} => %{
      "content" => [
        %{
          "text" => "Aight, got the ticker symbol GM for General Motors. Now let me look up that current stock price:\n\n<function_calls>\n<invoke>\n<tool_name>get_current_stock_price</tool_name>\n<parameters>\n<symbol>GM</symbol>\n</parameters>\n</invoke>\n",
          "type" => "text"
        }
      ],
      "id" => "msg_01QjBCr47TNUzpPvqnr5Yfn5",
      "model" => "claude-3-sonnet-20240229",
      "role" => "assistant",
      "stop_reason" => "stop_sequence",
      "stop_sequence" => "</function_calls>",
      "type" => "message",
      "usage" => %{"input_tokens" => 439, "output_tokens" => 77}
    },

    {:agent, :messages, 5} => %{
      "content" => [
        %{
          "text" => "Word, the current stock price for General Motors is $39.21. Representing that big auto money, ya dig? Gotta make them stacks and invest wisely in the motor city players.",
          "type" => "text"
        }
      ],
      "id" => "msg_01Nq9eY6wnrSSs5QDKYD9yHE",
      "model" => "claude-3-sonnet-20240229",
      "role" => "assistant",
      "stop_reason" => "end_turn",
      "stop_sequence" => nil,
      "type" => "message",
      "usage" => %{"input_tokens" => 553, "output_tokens" => 45}
    }
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

  @spec client(function()) :: Anthropix.t()
  def client(plug) when is_function(plug, 1) do
    struct(Anthropix, req: Req.new(plug: plug))
  end

  @spec respond(Plug.Conn.t(), term()) :: Plug.Conn.t()
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
