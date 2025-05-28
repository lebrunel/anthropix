defmodule Anthropix.Messages.ResponseTest do
  use ExUnit.Case, async: true
  alias Anthropix.Messages

  @raw_response Jason.decode!("""
  {
    "content": [
      {
        "text": "Hi! My name is Claude.",
        "type": "text"
      }
    ],
    "id": "msg_013Zva2CMHLNnXjNJJKqJ2EF",
    "model": "claude-3-7-sonnet-20250219",
    "role": "assistant",
    "stop_reason": "end_turn",
    "stop_sequence": null,
    "type": "message",
    "usage": {
      "input_tokens": 2095,
      "output_tokens": 503
    }
  }
  """)

  defp test_response(res) do
    # assert res.content .... #todo
    assert res.id == "msg_013Zva2CMHLNnXjNJJKqJ2EF"
    assert res.model == "claude-3-7-sonnet-20250219"
    assert res.role == "assistant"
    assert res.stop_reason == "end_turn"
    assert res.stop_sequence == nil
    assert res.type == "message"
    assert res.usage.input_tokens == 2095
    assert res.usage.output_tokens == 503
  end

  describe "new/1" do
    test "converts raw response to struct" do
      assert {:ok, %Messages.Response{} = res} = Messages.Response.new(@raw_response)
      test_response(res)
    end

    test "returns errors for invalid response" do
      assert {:error, errors} = Messages.Response.new(%{})
      assert Enum.all?(errors, & match?(%Peri.Error{}, &1))
    end
  end

  describe "new!" do
    test "converts raw response to struct" do
      assert %Messages.Response{} = res = Messages.Response.new!(@raw_response)
      test_response(res)
    end

    test "raises error for invalid response" do
      assert_raise Peri.InvalidSchema, fn ->
        Messages.Response.new!(%{})
      end
    end
  end
end
