defmodule AnthropixTest do
  use ExUnit.Case
  alias Anthropix.{APIError, Mock}

  describe "init without api_key" do
    test "raises if no api_key in config" do
      Application.delete_env(:anthropix, :api_key)
      assert_raise ArgumentError, fn -> Anthropix.init() end
    end

    test "creates client using api_key from config" do
      Application.put_env(:anthropix, :api_key, "test_key")
      client = Anthropix.init()
      assert ["test_key"] = client.req.headers["x-api-key"]
      Application.delete_env(:anthropix, :api_key)
    end
  end

  describe "init with api_key" do
    test "default client" do
      client = Anthropix.init("test_key")
      assert "https://api.anthropic.com/v1" = client.req.options.base_url
      assert %{"anthropic-version" => _val} = client.req.headers
      assert %{"user-agent" => _val} = client.req.headers
      assert %{"x-api-key" => ["test_key"]} = client.req.headers
    end

    test "client with custom req options" do
      client = Anthropix.init("test_key", receive_timeout: :infinity)
      assert "https://api.anthropic.com/v1" = client.req.options.base_url
      assert :infinity = client.req.options.receive_timeout
    end

    test "client with merged headers" do
      client = Anthropix.init("test_key", headers: [
        {"User-Agent", "testing"},
        {"X-Test", "testing"},
      ])
      assert %{"user-agent" => ["testing"], "x-test" => ["testing"]} = client.req.headers
    end
  end

  describe "chat/2" do
    test "generates a response for a given prompt" do
      client = Mock.client(& Mock.respond(&1, :messages))
      assert {:ok, res} = Anthropix.chat(client, [
        model: "claude-3-sonnet-20240229",
        messages: [
          %{role: "user", content: "Write a haiku about the colour of the sky."}
        ]
      ])
      assert res["model"] == "claude-3-sonnet-20240229"
      assert res["stop_reason"] == "end_turn"
      assert is_list(res["content"])
      assert Enum.all?(res["content"], &is_map/1)
    end

    test "streams a response for a given prompt" do
      client = Mock.client(& Mock.stream(&1, :messages))
      assert {:ok, stream} = Anthropix.chat(client, [
        model: "claude-3-sonnet-20240229",
        messages: [
          %{role: "user", content: "Write a haiku about the colour of the sky."}
        ],
        stream: true
      ])
      res = Enum.to_list(stream)
      last = Enum.find(res, & &1["type"] == "message_delta")
      assert is_list(res)
      assert get_in(last, ["delta", "stop_reason"]) == "end_turn"
      assert get_in(last, ["usage", "output_tokens"]) == 34
    end

    test "returns error when model not found" do
      client = Mock.client(& Mock.respond(&1, 404))
      assert {:error, %APIError{type: "not_found"}} = Anthropix.chat(client, [
        model: "not-found",
        messages: [
          %{role: "user", content: "Write a haiku about the colour of the sky."}
        ]
      ])
    end
  end

  describe "streaming methods" do
    test "with stream: true, returns a lazy enumerable" do
      client = Mock.client(& Mock.stream(&1, :messages))
      assert {:ok, stream} = Anthropix.chat(client, [
        model: "claude-3-sonnet-20240229",
        messages: [
          %{role: "user", content: "Write a haiku about the colour of the sky."}
        ],
        stream: true
      ])

      assert is_function(stream, 2)
      assert Enum.to_list(stream) |> length() == 31
    end

    test "with stream: pid, returns a task and sends messages to pid" do
      {:ok, pid} = Anthropix.StreamCatcher.start_link()
      client = Mock.client(& Mock.stream(&1, :messages))
      assert {:ok, task} = Anthropix.chat(client, [
        model: "claude-3-sonnet-20240229",
        messages: [
          %{role: "user", content: "Write a haiku about the colour of the sky."}
        ],
        stream: pid,
      ])

      assert match?(%Task{}, task)
      assert {:ok, %{"content" => [%{"text" => "Here's a haiku" <> _} | _]}} = Task.await(task)
      assert Anthropix.StreamCatcher.get_state(pid) |> length() == 31
      GenServer.stop(pid)
    end
  end

end
