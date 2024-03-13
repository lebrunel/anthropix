defmodule Anthropix.FunctionCallTest do
  use ExUnit.Case
  alias Anthropix.{FunctionCall, Tool}

  setup_all do
    function = %FunctionCall{
      name: "test",
      args: %{"a" => "1", "b" => "2"},
    }

    tool = %Tool{
      name: "test",
      params: [%{name: "a", type: "integer"}, %{name: "b", type: "integer"}],
      function: fn a, b -> String.to_integer(a) + String.to_integer(b) end
    }

    {:ok, fc: function, tool: tool}
  end

  describe "extract!/1" do
    test "parses valid function calls" do
      text = """
      Some juicy function calls here:

      <function_calls>
        <invoke>
          <tool_name>get_ticker_symbol</tool_name>
          <parameters>
            <company_name>General Motors</company_name>
          </parameters>
        </invoke>
      </function_calls>
      """

      assert [fc] = FunctionCall.extract!(text)
      assert fc.name == "get_ticker_symbol"
      assert %{"company_name" => "General Motors"} = fc.args
    end

    test "returns empty list if no matching xml" do
      assert [] = FunctionCall.extract!("no function calls in here mate")
    end
  end

  describe "invoke/2" do
    test "invokes a function using the matching tool", %{fc: fc, tool: tool} do
      assert %FunctionCall{} = fc = FunctionCall.invoke(fc, tool)
      assert fc.result == 3
    end
  end

  describe "invoke_all/2" do
    test "invokes all functions using the matching tools", %{fc: fc, tool: tool} do
      assert [fc] = FunctionCall.invoke_all([fc], [tool])
      assert fc.result == 3
    end

    test "returns an exception if any function raises", %{fc: fc} do
      tool = %Tool{
        name: "test",
        params: [%{name: "a", type: "integer"}, %{name: "b", type: "integer"}],
        function: fn _a, _b -> raise "some error" end
      }
      assert error = FunctionCall.invoke_all([fc], [tool])
      assert is_exception(error)
    end
  end
end
