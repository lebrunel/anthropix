defmodule Anthropix.Messages.RequestTest do
  use ExUnit.Case, async: true
  alias Anthropix.{Message, Messages}

  @client Anthropix.init("test")

  @minimum_params %{
    model: "claude-opus-4-20250514",
    messages: [%{role: "user", content: "Hello"}]
  }

  @kitchen_sink_params %{
    model: "claude-opus-4-20250514",
    messages: [%{role: "user", content: "Hello"}]
  }

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

    @tag :skip
    test "tools"
    # todo - accepts maps
    # todo - accepts structs
    # todo - accepts presets

    test "thinking can be disabled" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        thinking: %{type: "disabled"}
      }))
      assert body.thinking.type == "disabled"
    end

    test "thinking budget tokens is required and must be greater than or equal 1024 when thinking enabled" do
      assert {:ok, %{body: body}} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        thinking: %{type: "enabled", budget_tokens: 1024}
      }))
      assert body.thinking.budget_tokens == 1024

      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        thinking: %{type: "enabled"}
      }))
      assert includes_error?(errors, :budget_tokens)

      assert {:error, errors} = Messages.Request.new(@client, Map.merge(@minimum_params, %{
        thinking: %{type: "enabled", budget_tokens: 100}
      }))
      assert includes_error?(errors, :budget_tokens)
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
