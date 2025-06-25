defmodule Anthropix.MessagesTest do
  use ExUnit.Case, async: true
  alias Anthropix.{Messages, Tools, StreamingResponse}
  alias Anthropix.Mock2, as: Mock

  describe "generate/2 mocked" do
    test "generates text" do
      client = Anthropix.init(plug: Mock.respond("messages.text.json"))
      assert {:ok, response} = Messages.generate(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "Write a haiku about the sky."}]
      })

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "generates tool use" do
      client = Anthropix.init(plug: Mock.respond("messages.tools.json"))
      assert {:ok, response} = Messages.generate(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "What is John Smith's phone number?"}],
        tools: [%{
          type: "custom",
          name: "get_contact_details",
          description: "Look up and return a contact's address and phone number.",
          input_schema: %{
            type: "object",
            properties: %{
              name: %{type: "string", description: "The name of the contact"}
            },
            required: ["name"]
          }
        }]
      })

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
      assert Enum.any?(response.content, & &1.type == "tool_use" and &1.name == "get_contact_details")
    end

    test "generates extended thinking" do
      client = Anthropix.init(plug: Mock.respond("messages.thinking.json"))
      assert {:ok, response} = Messages.generate(client, %{
        model: "claude-sonnet-4-20250514",
        messages: [%{role: "user", content: "How many R's are in the word strawberry. Answer with a haiku."}],
        thinking: %{type: "enabled"}
      })

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "thinking" and is_binary(&1.thinking))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "generates with code execution tool" do
      client = Anthropix.init(plug: Mock.respond("messages.code-execution.json"))
      assert {:ok, response} = Messages.generate(client, %{
        model: "claude-3-5-haiku-latest",
        messages: [%{role: "user", content: "Calculate the mean and standard deviation of [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]. Answer with a haiku."}],
        tools: [Tools.CodeExecution.new!()]
      })

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "server_tool_use" and is_binary(&1.input.code))
      assert Enum.any?(response.content, & &1.type == "code_execution_tool_result" and is_map(&1.content))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "generates with web search tool" do
      client = Anthropix.init(plug: Mock.respond("messages.web-search.json"))
      assert {:ok, response} = Messages.generate(client, %{
        model: "claude-3-5-haiku-latest",
        messages: [%{role: "user", content: "When was Terry Nutkins born? Answer with a haiku."}],
        tools: [Tools.WebSearch.new!()]
      })

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "server_tool_use" and is_binary(&1.input.query))
      assert Enum.any?(response.content, & &1.type == "web_search_tool_result" and is_list(&1.content))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end
  end

  describe "generate/2 integration" do
    @describetag :integration

    setup do
      {:ok, client: Anthropix.init()}
    end

    test "handles simple text generation", %{client: client} do
      assert {:ok, response} = Messages.generate(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "Write a haiku about the sky."}]
      })

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "testing2", %{client: client} do
      assert {:ok, streaming} = Messages.stream(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "Write a haiku about the sky."}]
      })

      assert {:ok, response} = StreamingResponse.run(streaming)

      assert valid_response?(response)
    end
  end

  describe "stream/2 mocked" do
    test "streams text" do
      client = Anthropix.init(plug: Mock.stream("messages.text.jsonl"))
      assert {:ok, streaming} = Messages.stream(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "Write a haiku about the sky."}]
      })
      assert {:ok, response} = StreamingResponse.run(streaming)

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "streams tool use" do
      client = Anthropix.init(plug: Mock.stream("messages.tools.jsonl"))
      assert {:ok, streaming} = Messages.stream(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "What is John Smith's phone number?"}],
        tools: [%{
          type: "custom",
          name: "get_contact_details",
          description: "Look up and return a contact's address and phone number.",
          input_schema: %{
            type: "object",
            properties: %{
              name: %{type: "string", description: "The name of the contact"}
            },
            required: ["name"]
          }
        }]
      })
      assert {:ok, response} = StreamingResponse.run(streaming)

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
      assert Enum.any?(response.content, & &1.type == "tool_use" and &1.name == "get_contact_details")
    end

    test "streams extended thinking" do
      client = Anthropix.init(plug: Mock.stream("messages.thinking.jsonl"))
      assert {:ok, streaming} = Messages.stream(client, %{
        model: "claude-sonnet-4-20250514",
        messages: [%{role: "user", content: "How many R's are in the word strawberry. Answer with a haiku."}],
        thinking: %{type: "enabled"}
      })
      assert {:ok, response} = StreamingResponse.run(streaming)

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "thinking" and is_binary(&1.thinking))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "streams with code execution tool" do
      client = Anthropix.init(plug: Mock.stream("messages.code-execution.jsonl"))
      assert {:ok, streaming} = Messages.stream(client, %{
        model: "claude-3-5-haiku-latest",
        messages: [%{role: "user", content: "Calculate the mean and standard deviation of [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]. Answer with a haiku."}],
        tools: [Tools.CodeExecution.new!()]
      })
      assert {:ok, response} = StreamingResponse.run(streaming)

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "server_tool_use" and is_binary(&1.input.code))
      assert Enum.any?(response.content, & &1.type == "code_execution_tool_result" and is_map(&1.content))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "streams with web search tool" do
      client = Anthropix.init(plug: Mock.stream("messages.web-search.jsonl"))
      assert {:ok, streaming} = Messages.stream(client, %{
        model: "claude-sonnet-4-20250514",
        messages: [%{role: "user", content: "When was Terry Nutkins born? Answer with a haiku."}],
        tools: [Tools.WebSearch.new!()]
      })
      assert {:ok, response} = StreamingResponse.run(streaming)

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "server_tool_use" and is_binary(&1.input.query))
      assert Enum.any?(response.content, & &1.type == "web_search_tool_result" and is_list(&1.content))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "streaming response returns an API error" do
      client = Anthropix.init(plug: Mock.stream("overloaded.jsonl"))
      assert {:ok, streaming} = Messages.stream(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "Write a haiku about the sky."}]
      })
      assert {:error, error} = StreamingResponse.run(streaming)

      assert error.type == "overloaded_error"
      assert error.message == "Overloaded"
    end
  end

  describe "count_tokens/1 mocked" do
    test "returns the number of input tokens" do
      client = Anthropix.init(plug: Mock.respond("messages.tokens.json"))

      assert {:ok, res} = Messages.count_tokens(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "Write a haiku about the sky."}]
      })
      assert res.input_tokens == 15
    end
  end

  @spec valid_response?(term()) :: :ok
  defp valid_response?(res) do
    assert match?(%Messages.Response{}, res)
    assert is_binary(res.id)
    assert is_binary(res.model)
    assert res.type == "message"
    assert res.role == "assistant"
    assert is_list(res.content)
    assert is_binary(res.stop_reason)
    assert is_map(res.usage)
    assert is_integer(res.usage.input_tokens)
    assert is_integer(res.usage.output_tokens)
    assert is_binary(res.usage.service_tier)
    assert match?(%Req.Response{}, res.raw)
    :ok
  end
end
