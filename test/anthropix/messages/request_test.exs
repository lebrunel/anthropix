defmodule Anthropix.Messages.RequestTest do
  use ExUnit.Case, async: true
  import Anthropix.TestHelpers
  alias Anthropix.{Message, Messages, Tool}

  @minimum_params %{
    model: "claude-opus-4-20250514",
    messages: [%{role: "user", content: "Hello"}]
  }

  # todo - test for kitchen sink params
  #@kitchen_sink_params %{
  #  model: "claude-opus-4-20250514",
  #  messages: [%{role: "user", content: "Hello"}]
  #}

  describe "request/1 body params" do
    test "accepts valid params" do
      assert {:ok, _params} = Messages.Request.request(@minimum_params)
    end

    test "model is required" do
      assert {:error, errors} = Messages.Request.request(%{})
      assert includes_error?(errors, :model)
    end

    test "messages is required" do
      assert {:error, errors} = Messages.Request.request(%{})
      assert includes_error?(errors, :messages)
    end

    test "messages can be maps or structs" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        messages: [
          %{role: "user", content: "Hello"},
          Message.new!(:assistant, "Hi!")
        ]
      }))
      assert length(request.messages) == 2
    end

    test "system can be a string or list of text block maps" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        system: "test"
      }))
      assert request.system == "test"
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        system: [%{type: "text", text: "test"}]
      }))
      assert request.system == [%{type: "text", text: "test"}]
    end

    test "tool_choice type must be valid option" do
      for type <- ["auto", "any", "none"] do
        assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
          tool_choice: %{type: type}
        }))
        assert request.tool_choice.type == type
      end

      assert {:error, errors} = Messages.Request.request(Map.merge(@minimum_params, %{
        tool_choice: %{type: "invalid"}
      }))
      assert includes_error?(errors, :tool_choice)
    end

    test "tool_choice name is required when type is tool" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        tool_choice: %{type: "tool", name: "test"}
      }))
      assert request.tool_choice.name == "test"

      assert {:error, errors} = Messages.Request.request(Map.merge(@minimum_params, %{
        tool_choice: %{type: "tool"}
      }))
      assert includes_error?(errors, :tool_choice)
    end

    test "tools can be maps or structs" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        tools: [
          %{name: "test1", input_schema: %{type: "null"}},
          Tool.new!(name: "test2", input_schema: %{type: "null"})
        ]
      }))
      assert length(request.tools) == 2
    end

    test "thinking can be disabled" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        thinking: %{type: "disabled"}
      }))
      assert request.thinking.type == "disabled"
    end

    test "thinking budget tokens defaults to 1024 and must be greater than or equal 1024 when thinking enabled" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        thinking: %{type: "enabled"}
      }))
      assert request.thinking.budget_tokens == 1024

      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        thinking: %{type: "enabled", budget_tokens: 1024}
      }))
      assert request.thinking.budget_tokens == 1024

      assert {:error, errors} = Messages.Request.request(Map.merge(@minimum_params, %{
        thinking: %{type: "enabled", budget_tokens: 100}
      }))
      assert includes_error?(errors, :thinking)
    end

    test "container must be a string" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        container: "test"
      }))
      assert request.container == "test"

      assert {:error, errors} = Messages.Request.request(Map.merge(@minimum_params, %{
        container: 123
      }))
      assert includes_error?(errors, :container)
    end

    test "mcp_servers msut be valid maps" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
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
      server = hd(request.mcp_servers)
      assert server.type == "url"
      assert server.name == "test"
      assert server.url == "https://example.com"
      assert server.authorization_token == "test"
      assert server.tool_configuration.enabled == true
      assert server.tool_configuration.allowed_tools == ["test"]
    end

    test "metadata accepts user_id" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        metadata: %{user_id: "test"}
      }))
      assert request.metadata.user_id == "test"

      assert {:error, errors} = Messages.Request.request(Map.merge(@minimum_params, %{
        metadata: 123
      }))
      assert includes_error?(errors, :metadata)
    end

    test "service_tier type must be valid option" do
      for tier <- ["auto", "standard_only"] do
        assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
          service_tier: tier
        }))
        assert request.service_tier == tier
      end

      assert {:error, errors} = Messages.Request.request(Map.merge(@minimum_params, %{
        service_tier: "invalid"
      }))
      assert includes_error?(errors, :service_tier)
    end

    test "max_tokens defaults to 4096" do
      assert {:ok, request} = Messages.Request.request(@minimum_params)
      assert request.max_tokens == 4096
    end

    test "max_tokens must be gte 1" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        max_tokens: 1
      }))
      assert request.max_tokens == 1

      assert {:error, errors} = Messages.Request.request(Map.merge(@minimum_params, %{
        max_tokens: 0
      }))
      assert includes_error?(errors, :max_tokens)
    end

    test "stop_sequences must be a list of strings" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        stop_sequences: ["foo", "bar"]
      }))
      assert request.stop_sequences == ["foo", "bar"]

      assert {:error, errors} = Messages.Request.request(Map.merge(@minimum_params, %{
        stop_sequences: "foo bar"
      }))
      assert includes_error?(errors, :stop_sequences)
    end

    test "temperature must be a float between 0 and 1" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        temperature: 0.5
      }))
      assert request.temperature == 0.5

      for temperature <- [-0.1, 1.1] do
        assert {:error, errors} = Messages.Request.request(Map.merge(@minimum_params, %{
          temperature: temperature
        }))
        assert includes_error?(errors, :temperature)
      end
    end

    test "top_k must be gte 1" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        top_k: 1
      }))
      assert request.top_k == 1

      assert {:error, errors} = Messages.Request.request(Map.merge(@minimum_params, %{
        top_k: 0
      }))
      assert includes_error?(errors, :top_k)
    end

    test "top_p must be a float between 0 and 1" do
      assert {:ok, request} = Messages.Request.request(Map.merge(@minimum_params, %{
        top_p: 0.5
      }))
      assert request.top_p == 0.5

      for top_p <- [-0.1, 1.1] do
        assert {:error, errors} = Messages.Request.request(Map.merge(@minimum_params, %{
          top_p: top_p
        }))
        assert includes_error?(errors, :top_p)
      end
    end
  end

end
