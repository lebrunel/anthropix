defmodule Anthropix.XMLTest do
  use ExUnit.Case
  alias Anthropix.{FunctionCall, Tool, XML}
  doctest XML

  describe "encode/2" do
    test "encode tool descriptions into XML" do
      tools = [
        %Tool{name: "a", description: "aaa", params: [%{name: "b", description: "bbb", type: "string"}]},
        %Tool{name: "c", description: "ccc", params: [%{name: "d", description: "ddd", type: "integer"}]},
      ]
      xml = XML.encode(:tools, tools)
      assert is_binary(xml)
      assert Regex.match?(~r/^<tools>.+<\/tools>$/, xml)
      assert res = Regex.scan(~r/<tool_name>(.)<\/tool_name>/, xml)
      assert length(res) == 2
    end

    test "encode function results into XML" do
      functions = [
        %FunctionCall{name: "a", result: "aaa"},
        %FunctionCall{name: "c", result: "123"},
      ]
      xml = XML.encode(:function_results, functions)
      assert is_binary(xml)
      assert Regex.match?(~r/^<function_results>.+<\/function_results>$/, xml)
      assert res = Regex.scan(~r/<tool_name>(.)<\/tool_name>/, xml)
      assert length(res) == 2
    end

    test "wont accept any other type" do
      assert_raise FunctionClauseError, fn ->
        XML.encode(:whatever, "any value")
      end
    end

  end
end
