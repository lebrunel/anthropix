defmodule Anthropix.ToolTest do
  use ExUnit.Case
  alias Anthropix.Tool

  defmodule TestModule do
    def my_func(_a), do: "xxx"
    def my_func_extra(_a, _b, _c), do: "xxx"
  end

  describe "new/1" do
    setup do
      {:ok, params: [
        name: "test",
        description: "A test tool",
        params: [
          %{name: "a", description: "aaa", type: "string"}
        ]
      ]}
    end

    test "returns a Tool with anonymous function", %{params: params} do
      params = Keyword.put(params, :function, fn _a -> "xxx" end)
      assert %Tool{} = Tool.new(params)
    end

    test "raises with anonymous function with incorrect arity", %{params: params} do
      params = Keyword.put(params, :function, fn _a, _b, _c -> "xxx" end)
      assert_raise NimbleOptions.ValidationError, fn -> Tool.new(params) end
    end

    test "returns a Tool with referenced function", %{params: params} do
      params = Keyword.put(params, :function, &TestModule.my_func/1)
      assert %Tool{} = Tool.new(params)
    end

    test "raises with referenced function with incorrect arity", %{params: params} do
      params = Keyword.put(params, :function, &TestModule.my_func_extra/3)
      assert_raise NimbleOptions.ValidationError, fn -> Tool.new(params) end
    end

    test "returns a Tool with MFA function", %{params: params} do
      params = Keyword.put(params, :function, {TestModule, :my_func_extra, [1, 2]})
      assert %Tool{} = Tool.new(params)
    end

    test "raises with MFA function with incorrect arity", %{params: params} do
      params = Keyword.put(params, :function, {TestModule, :my_func, [1, 2]})
      assert_raise NimbleOptions.ValidationError, fn -> Tool.new(params) end
    end
  end

end
