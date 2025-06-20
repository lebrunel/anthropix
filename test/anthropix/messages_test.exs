defmodule Anthropix.MessagesTest do
  use ExUnit.Case, async: true
  alias Anthropix.Messages
  alias Anthropix.Mock2, as: Mock

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
end
