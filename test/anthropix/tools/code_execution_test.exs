defmodule Anthropix.Tools.CodeExecutionTest do
  use ExUnit.Case, async: true
  alias Anthropix.Tools.CodeExecution
  alias Anthropix.Tool

  describe "new/1" do
    test "initializes with default config" do
      assert {:ok, %Tool{} = tool} = CodeExecution.new()
      assert tool.type == :server
      assert tool.name == "code_execution"
      assert tool.config.type == "code_execution_20250522"
    end
  end

  describe "Tool.to_map/1" do
    test "returns a map representation of the tool" do
      assert {:ok, %Tool{} = tool} = CodeExecution.new(cache_control: %{type: "ephemeral", ttl: "5m"})
      assert %{
        type: "code_execution_20250522",
        name: "code_execution",
        cache_control: %{type: "ephemeral", ttl: "5m"}
      } = Tool.to_map(tool)
    end
  end
end
