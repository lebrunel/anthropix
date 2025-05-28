defmodule Anthropix.MessageTest do
  use ExUnit.Case, async: true
  alias Anthropix.Message

  @valid_content_blocks [
    %{type: "text", text: "test"},
    %{type: "image", source: %{type: "base64", media_type: "image/png", data: "test"}},
    %{type: "document", source: %{type: "base64", media_type: "image/png", data: "test"}},
    %{type: "thinking", thinking: "test", signature: "test"},
    %{type: "redacted_thinking", data: "test"},
    %{type: "tool_use", id: "test", name: "test", input: %{}},
    %{type: "tool_result", tool_use_id: "test", content: "test"},
    %{type: "mcp_tool_use", id: "test", name: "test", server_name: "test", input: %{}},
    %{type: "mcp_tool_result", tool_use_id: "test", content: "test"},
    %{type: "server_tool_use", id: "test", name: "web_search", input: %{}},
    %{type: "web_search_tool_result", tool_use_id: "test", content: [
      %{type: "web_search_result", title: "test", encrypted_content: "test", url: "test", page_age: "1"}
    ]},
    %{type: "web_search_tool_result", tool_use_id: "test", content: %{
      type: "web_search_tool_result_error",
      error_code: "test"
    }},
    %{type: "code_execution_tool_result", tool_use_id: "test", content: %{
      type: "code_execution_result",
      content: [%{type: "code_execution_output", file_id: "test"}],
      return_code: 1,
      stdout: "",
      stderr: ""
    }},
    %{type: "code_execution_tool_result", tool_use_id: "test", content: %{
      type: "code_execution_tool_result_error",
      error_code: "test"
    }}
  ]

  describe "new/1" do
    test "accepts user and assistant roles" do
      for role <- ["user", "assistant"] do
        assert {:ok, %Message{role: ^role}} = Message.new(role: role, content: "test")
      end
    end

    test "returns error for invalid role" do
      assert {:error, errors} = Message.new(role: "invalid", content: "test")
      assert Enum.any?(errors, & match?(%Peri.Error{}, &1) and &1.key == :role)
    end

    test "converts string content into text content block" do
      assert {:ok, message} = Message.new(role: "user", content: "test")
      assert message.content == [%{type: "text", text: "test"}]
    end

    test "accepts array of valid content blocks" do
      assert {:ok, message} = Message.new(role: "user", content: @valid_content_blocks)
      assert length(message.content) == length(@valid_content_blocks)
    end

    test "returns error for invalid content" do
      assert {:error, errors} = Message.new(role: "user", content: [
        %{type: "invalid", foo: "bar"}
      ])
      assert Enum.any?(errors, & match?(%Peri.Error{}, &1) and &1.key == :content)
    end

    test "image content blocks accepts valid sources" do
      content = [
        %{type: "image", source: %{type: "base64", media_type: "image/png", data: "test"}},
        %{type: "image", source: %{type: "url", url: "test"}},
        %{type: "image", source: %{type: "file", file_id: "test"}},
      ]

      assert {:ok, message} = Message.new(role: "user", content: content)
      assert length(message.content) == length(content)
    end

    test "returns error for image block with invalid source" do
      assert {:error, errors} = Message.new(role: "user", content: [
        %{type: "image", source: %{type: "invalid", foo: "bar"}},
      ])
      assert Enum.any?(errors, & match?(%Peri.Error{}, &1) and &1.key == :content)
    end

    test "document content blocks accepts valid sources" do
      content = [
        %{type: "document", title: "test", source: %{type: "base64", media_type: "image/png", data: "test"}},
        %{type: "document", title: "test", source: %{type: "text", media_type: "text/plain", data: "test"}},
        %{type: "document", title: "test", source: %{type: "content", content: "test"}},
        %{type: "document", title: "test", source: %{type: "url", url: "test"}},
        %{type: "document", title: "test", source: %{type: "file", file_id: "test"}},
      ]

      assert {:ok, message} = Message.new(role: "user", content: content)
      assert length(message.content) == length(content)
    end

    test "returns error for document block with invalid source" do
      assert {:error, errors} = Message.new(role: "user", content: [
        %{type: "document", source: %{type: "invalid", foo: "bar"}},
      ])
      assert Enum.any?(errors, & match?(%Peri.Error{}, &1) and &1.key == :content)
    end

    test "tool_result content block accepts valid nested content blocks" do
      assert {:ok, _message} = Message.new(role: "user", content: [
        %{type: "tool_result", tool_use_id: "test", content: [
          %{type: "text", text: "test"},
          %{type: "image", source: %{type: "base64", media_type: "image/png", data: "test"}},
        ]}
      ])
    end

    test "mcp_tool_result content block accepts valid nested content blocks" do
      assert {:ok, _message} = Message.new(role: "user", content: [
        %{type: "mcp_tool_result", tool_use_id: "test", content: [
          %{type: "text", text: "test"}
        ]}
      ])
    end
  end

  describe "new!/1" do
    test "accepts user and assistant roles" do
      for role <- ["user", "assistant"] do
        assert %Message{role: ^role} = Message.new!(role: role, content: "test")
      end
    end

    test "raises error for invalid role" do
      assert_raise Peri.InvalidSchema, fn ->
        Message.new!(role: "invalid", content: "test")
      end
    end

    test "accepts array of valid content blocks" do
      assert message = Message.new!(role: "user", content: @valid_content_blocks)
      assert length(message.content) == length(@valid_content_blocks)
    end

    test "raises error for invalid content blocks" do
      assert_raise Peri.InvalidSchema, fn ->
        Message.new!(role: "user", content: [
          %{type: "invalid", foo: "bar"}
        ])
      end
    end
  end

  describe "new/2" do
    test "accepts user and assistant roles" do
      for role <- ["user", "assistant"] do
        assert {:ok, %Message{role: ^role}} = Message.new(role, "test")
      end
    end

    test "accepts user and assistant roles as atoms" do
      for role <- [:user, :assistant] do
        str_role = Atom.to_string(role)
        assert {:ok, %Message{role: ^str_role}} = Message.new(role, "test")
      end
    end

    test "returns error for invalid role" do
      assert {:error, errors} = Message.new("invalid", "test")
      assert Enum.any?(errors, & match?(%Peri.Error{}, &1) and &1.key == :role)
    end

    test "accepts array of valid content blocks" do
      assert {:ok, message} = Message.new("user", @valid_content_blocks)
      assert length(message.content) == length(@valid_content_blocks)
    end

    test "returns error for invalid content" do
      assert {:error, errors} = Message.new("user", [
        %{type: "invalid", foo: "bar"}
      ])
      assert Enum.any?(errors, & match?(%Peri.Error{}, &1) and &1.key == :content)
    end
  end

  describe "new!/2" do
    test "accepts user and assistant roles" do
      for role <- ["user", "assistant"] do
        assert %Message{role: ^role} = Message.new!(role, "test")
      end
    end

    test "accepts user and assistant roles as atoms" do
      for role <- [:user, :assistant] do
        str_role = Atom.to_string(role)
        assert %Message{role: ^str_role} = Message.new!(role, "test")
      end
    end

    test "returns error for invalid role" do
      assert_raise Peri.InvalidSchema, fn ->
        Message.new!("invalid", "test")
      end
    end

    test "accepts array of valid content blocks" do
      assert message = Message.new!("user", @valid_content_blocks)
      assert length(message.content) == length(@valid_content_blocks)
    end

    test "returns error for invalid content" do
      assert_raise Peri.InvalidSchema, fn ->
        Message.new!("user", [
          %{type: "invalid", foo: "bar"}
        ])
      end
    end
  end
end
