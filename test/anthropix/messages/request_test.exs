defmodule Anthropix.Messages.RequestTest do
  use ExUnit.Case, async: true
  alias Anthropix.{Message, Messages, Tool, Tools}
  alias Anthropix.Mock2, as: Mock

  @client Anthropix.init("test")

  @minimum_params %{
    model: "claude-opus-4-20250514",
    messages: [%{role: "user", content: "Hello"}]
  }

  # todo - test for kitchen sink params
  #@kitchen_sink_params %{
  #  model: "claude-opus-4-20250514",
  #  messages: [%{role: "user", content: "Hello"}]
  #}

  describe "new/2" do
    test "accepts valid params" do
      assert {:ok, %Messages.Request{}} = Messages.Request.new(@client, @minimum_params)
    end

    test "model is required" do
      assert {:error, errors} = Messages.Request.new(@client, %{})
      assert includes_error?(errors, :model)
    end

    test "messages is required" do
      assert {:error, errors} = Messages.Request.new(@client, %{})
      assert includes_error?(errors, :messages)
    end
  end

  describe "new/2 body params" do
    test "messages can be maps or structs" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        messages: [
          %{role: "user", content: "Hello"},
          Message.new!(:assistant, "Hi!")
        ]
      }))
      assert length(body.messages) == 2
    end

    test "system can be a string or list of text block maps" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        system: "test"
      }))
      assert body.system == "test"
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        system: [%{type: "text", text: "test"}]
      }))
      assert body.system == [%{type: "text", text: "test"}]
    end

    test "tool_choice type must be valid option" do
      for type <- ["auto", "any", "none"] do
        assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
          tool_choice: %{type: type}
        }))
        assert body.tool_choice.type == type
      end

      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        tool_choice: %{type: "invalid"}
      }))
      assert includes_error?(errors, :tool_choice)
    end

    test "tool_choice name is required when type is tool" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        tool_choice: %{type: "tool", name: "test"}
      }))
      assert body.tool_choice.name == "test"

      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        tool_choice: %{type: "tool"}
      }))
      assert includes_error?(errors, :tool_choice)
    end

    test "tools can be maps or structs" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        tools: [
          %{name: "test1", input_schema: %{type: "null"}},
          Tool.new!(name: "test2", input_schema: %{type: "null"})
        ]
      }))
      assert length(body.tools) == 2
    end

    test "thinking can be disabled" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        thinking: %{type: "disabled"}
      }))
      assert body.thinking.type == "disabled"
    end

    test "thinking budget tokens defaults to 1024 and must be greater than or equal 1024 when thinking enabled" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        thinking: %{type: "enabled"}
      }))
      assert body.thinking.budget_tokens == 1024

      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        thinking: %{type: "enabled", budget_tokens: 1024}
      }))
      assert body.thinking.budget_tokens == 1024

      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        thinking: %{type: "enabled", budget_tokens: 100}
      }))
      assert includes_error?(errors, :thinking)
    end

    test "container must be a string" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        container: "test"
      }))
      assert body.container == "test"

      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        container: 123
      }))
      assert includes_error?(errors, :container)
    end

    test "mcp_servers msut be valid maps" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        mcp_servers: [%{
          type: "url",
          name: "test",
          url: "https://example.com",
          authorization_token: "test",
          tool_configuration: %{
            enabled: true,
            allowed_tools: ["test"]
          }
        }]
      }))
      server = hd(body.mcp_servers)
      assert server.type == "url"
      assert server.name == "test"
      assert server.url == "https://example.com"
      assert server.authorization_token == "test"
      assert server.tool_configuration.enabled == true
      assert server.tool_configuration.allowed_tools == ["test"]
    end

    test "metadata accepts user_id" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        metadata: %{user_id: "test"}
      }))
      assert body.metadata.user_id == "test"

      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        metadata: 123
      }))
      assert includes_error?(errors, :metadata)
    end

    test "service_tier type must be valid option" do
      for tier <- ["auto", "standard_only"] do
        assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
          service_tier: tier
        }))
        assert body.service_tier == tier
      end

      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        service_tier: "invalid"
      }))
      assert includes_error?(errors, :service_tier)
    end

    test "max_tokens defaults to 4096" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, @minimum_params)
      assert body.max_tokens == 4096
    end

    test "max_tokens must be gte 1" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        max_tokens: 1
      }))
      assert body.max_tokens == 1

      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        max_tokens: 0
      }))
      assert includes_error?(errors, :max_tokens)
    end

    test "stop_sequences must be a list of strings" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        stop_sequences: ["foo", "bar"]
      }))
      assert body.stop_sequences == ["foo", "bar"]

      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        stop_sequences: "foo bar"
      }))
      assert includes_error?(errors, :stop_sequences)
    end

    test "temperature must be a float between 0 and 1" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        temperature: 0.5
      }))
      assert body.temperature == 0.5

      for temperature <- [-0.1, 1.1] do
        assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
          temperature: temperature
        }))
        assert includes_error?(errors, :temperature)
      end
    end

    test "top_k must be gte 1" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        top_k: 1
      }))
      assert body.top_k == 1

      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        top_k: 0
      }))
      assert includes_error?(errors, :top_k)
    end

    test "top_p must be a float between 0 and 1" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        top_p: 0.5
      }))
      assert body.top_p == 0.5

      for top_p <- [-0.1, 1.1] do
        assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
          top_p: top_p
        }))
        assert includes_error?(errors, :top_p)
      end
    end
  end

  describe "new/2 options" do
    test "initialized with default options" do
      assert {:ok, %{options: opts}} = Messages.Request.new(@client, @minimum_params)
      assert opts.max_retries == 2
      assert opts.max_steps == 1
    end

    test "can set custom options" do
      assert {:ok, %{options: opts}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        max_retries: 99,
        max_steps: 99
      }))
      assert opts.max_retries == 99
      assert opts.max_steps == 99
    end

    test "max_retries must be gte 0" do
      assert {:ok, %{options: opts}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        max_retries: 0
      }))
      assert opts.max_retries == 0
      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        max_retries: -1
      }))
      assert includes_error?(errors, :max_retries)
    end

    test "max_steps must be gte 1" do
      assert {:ok, %{options: opts}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        max_steps: 1
      }))
      assert opts.max_steps == 1
      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        max_steps: 0
      }))
      assert includes_error?(errors, :max_steps)
    end
  end

  describe "call/1 mocked" do
    test "generates text" do
      client = Anthropix.init(plug: Mock.respond("messages.text.json"))
      assert {:ok, request} = Messages.Request.new(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "Write a haiku about the sky."}]
      })
      assert {:ok, response} = Messages.Request.call(request)

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "generates tool use" do
      client = Anthropix.init(plug: Mock.respond("messages.tools.json"))
      assert {:ok, request} = Messages.Request.new(client, %{
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
      assert {:ok, response} = Messages.Request.call(request)

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
      assert Enum.any?(response.content, & &1.type == "tool_use" and &1.name == "get_contact_details")
    end

    test "generates extended thinking" do
      client = Anthropix.init(plug: Mock.respond("messages.thinking.json"))
      assert {:ok, request} = Messages.Request.new(client, %{
        model: "claude-sonnet-4-20250514",
        messages: [%{role: "user", content: "How many R's are in the word strawberry. Answer with a haiku."}],
        thinking: %{type: "enabled"}
      })
      assert {:ok, response} = Messages.Request.call(request)

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "thinking" and is_binary(&1.thinking))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "generates with code execution tool" do
      client = Anthropix.init(plug: Mock.respond("messages.code-execution.json"))
      assert {:ok, request} = Messages.Request.new(client, %{
        model: "claude-3-5-haiku-latest",
        messages: [%{role: "user", content: "Calculate the mean and standard deviation of [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]. Answer with a haiku."}],
        tools: [Tools.CodeExecution.new!()]
      })
      assert {:ok, response} = Messages.Request.call(request)

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "server_tool_use" and is_binary(&1.input.code))
      assert Enum.any?(response.content, & &1.type == "code_execution_tool_result" and is_map(&1.content))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "generates with web search tool" do
      client = Anthropix.init(plug: Mock.respond("messages.web-search.json"))
      assert {:ok, request} = Messages.Request.new(client, %{
        model: "claude-3-5-haiku-latest",
        messages: [%{role: "user", content: "When was Terry Nutkins born? Answer with a haiku."}],
        tools: [Tools.WebSearch.new!()]
      })
      assert {:ok, response} = Messages.Request.call(request)

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "server_tool_use" and is_binary(&1.input.query))
      assert Enum.any?(response.content, & &1.type == "web_search_tool_result" and is_list(&1.content))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end
  end

  describe "stream/1 mocked" do
    test "streams text" do
      client = Anthropix.init(plug: Mock.stream("messages.text.jsonl"))
      assert {:ok, request} = Messages.Request.new(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "Write a haiku about the sky."}]
      })
      assert {:ok, response} =
        Messages.Request.stream(request)
        |> Messages.StreamingResponse.run()

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "streams tool use" do
      client = Anthropix.init(plug: Mock.stream("messages.tools.jsonl"))
      #client = Anthropix.init()
      assert {:ok, request} = Messages.Request.new(client, %{
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
      assert {:ok, response} =
        Messages.Request.stream(request)
        |> Messages.StreamingResponse.run()

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
      assert Enum.any?(response.content, & &1.type == "tool_use" and &1.name == "get_contact_details")
    end

    test "streams extended thinking" do
      client = Anthropix.init(plug: Mock.stream("messages.thinking.jsonl"))
      assert {:ok, request} = Messages.Request.new(client, %{
        model: "claude-sonnet-4-20250514",
        messages: [%{role: "user", content: "How many R's are in the word strawberry. Answer with a haiku."}],
        thinking: %{type: "enabled"}
      })
      assert {:ok, response} =
        Messages.Request.stream(request)
        |> Messages.StreamingResponse.run()

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "thinking" and is_binary(&1.thinking))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "streams with code execution tool" do
      client = Anthropix.init(plug: Mock.stream("messages.code-execution.jsonl"))
      assert {:ok, request} = Messages.Request.new(client, %{
        model: "claude-3-5-haiku-latest",
        messages: [%{role: "user", content: "Calculate the mean and standard deviation of [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]. Answer with a haiku."}],
        tools: [Tools.CodeExecution.new!()]
      })
      assert {:ok, response} =
        Messages.Request.stream(request)
        |> Messages.StreamingResponse.run()

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "server_tool_use" and is_binary(&1.input.code))
      assert Enum.any?(response.content, & &1.type == "code_execution_tool_result" and is_map(&1.content))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "streams with web search tool" do
      client = Anthropix.init(plug: Mock.stream("messages.web-search.jsonl"))
      assert {:ok, request} = Messages.Request.new(client, %{
        model: "claude-sonnet-4-20250514",
        messages: [%{role: "user", content: "When was Terry Nutkins born? Answer with a haiku."}],
        tools: [Tools.WebSearch.new!()]
      })
      assert {:ok, response} =
        Messages.Request.stream(request)
        |> Messages.StreamingResponse.run()

      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "server_tool_use" and is_binary(&1.input.query))
      assert Enum.any?(response.content, & &1.type == "web_search_tool_result" and is_list(&1.content))
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end
  end

  describe "call/1 integration" do
    @describetag :integration

    setup do
      {:ok, client: Anthropix.init()}
    end

    test "handles simple text generation", %{client: client} do
      assert {:ok, request} = Messages.Request.new(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "Write a haiku about the sky."}]
      })

      assert {:ok, response} = Messages.Request.call(request)
      assert valid_response?(response)
      assert Enum.any?(response.content, & &1.type == "text" and is_binary(&1.text))
    end

    test "testing2", %{client: client} do
      assert {:ok, request} = Messages.Request.new(client, %{
        model: "claude-3-5-haiku-20241022",
        messages: [%{role: "user", content: "Write a haiku about the sky."}]
      })

      assert {:ok, response} =
        Messages.Request.stream(request)
        |> Messages.StreamingResponse.run()

        assert valid_response?(response)
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

  # todo
  @spec includes_error?(Peri.Error.t(), atom() | list(atom())) :: boolean()
  defp includes_error?(%Peri.Error{key: key}, key) when is_atom(key), do: true
  defp includes_error?(%Peri.Error{path: path}, path) when is_list(path), do: true

  defp includes_error?(%Peri.Error{errors: errors}, key) when is_list(errors),
    do: Enum.any?(errors, &includes_error?(&1, key))

  defp includes_error?(errors, key) when is_list(errors),
    do: Enum.any?(errors, &includes_error?(&1, key))

  defp includes_error?(%Peri.Error{}, _key), do: false

end
