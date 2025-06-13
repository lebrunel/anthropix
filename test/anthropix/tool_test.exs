defmodule Anthropix.ToolTest do
  use ExUnit.Case, async: true
  alias Anthropix.Tool

  @valid_tool_params %{
    name: "hello_world",
    description: "Say hello to the world",
    input_schema: Xema.new({:map, properties: %{"name" => :string}, required: ["name"]}),
    handler: {__MODULE__, :hello_world, []}
  }

  def hello_world(%{"name" => name}), do: "Hello #{name}"

  describe "new/1" do
    test "type defaults to :custom" do
      assert {:ok, %Tool{} = tool} = Tool.new(@valid_tool_params)
      assert tool.type == :custom
    end

    test "name and input_schema is required for custom tools" do
      assert {:error, errors} = Tool.new([])
      assert length(errors) == 2
      assert includes_error?(errors, :name)
      assert includes_error?(errors, :input_schema)
    end

    test "name is required for client and server tools" do
      for type <- [:client, :server] do
        assert {:error, errors} = Tool.new(type: type)
        assert length(errors) == 1
        assert includes_error?(errors, :name)
      end
    end

    test "input_schema accepts a valid Xema schema" do
      assert {:ok, %Tool{} = tool} = Tool.new(name: "hello_world", input_schema: Xema.new(:string))
      assert %Xema{} = tool.input_schema
    end

    test "input_schema accepts a JSON schema map" do
      for schema <- [%{type: "string"}, %{"type" => "string"}] do
        assert {:ok, %Tool{} = tool} = Tool.new(name: "hello_world", input_schema: schema)
        assert tool.input_schema == schema
      end
    end

    test "handler accepts an anonymous function" do
      assert {:ok, %Tool{} = tool} = Tool.new(Map.put(@valid_tool_params, :handler, fn _ -> "hello" end))
      assert is_function(tool.handler, 1)
    end

    test "handler accepts an MFA tuple" do
      assert {:ok, %Tool{handler: {mod, fun, args}}} = Tool.new(Map.put(@valid_tool_params, :handler, {__MODULE__, :hello_world, []}))
      assert function_exported?(mod, fun, length(args) + 1)
    end

    test "returns error if handler MFA is not valid" do
      assert {:error, errors} = Tool.new(handler: {__MODULE__, :not_exists, []})
      assert includes_error?(errors, :handler)
    end

    test "returns error on invalid values" do
      assert {:error, errors} = Tool.new(type: :invalid, name: :invalid, input_schema: :invalid, handler: :invalid, config: :invalid)
      assert includes_error?(errors, :type)
      assert includes_error?(errors, :name)
      assert includes_error?(errors, :input_schema)
      assert includes_error?(errors, :handler)
      assert includes_error?(errors, :config)
    end
  end

  describe "new!/1" do
    test "accepts valid params" do
      assert %Tool{} = tool = Tool.new!(@valid_tool_params)
      assert tool.type == :custom
    end

    test "returns error for invalid params" do
      assert_raise Peri.InvalidSchema, fn ->
        Tool.new!([])
      end
    end
  end

  describe "invoke/2" do
    test "calls function handler with input args" do
      assert {:ok, %Tool{} = tool} = Tool.new(Map.put(@valid_tool_params, :handler, fn %{"name" => name} -> "Hello #{name}" end))
      assert {:ok, "Hello world"} = Tool.invoke(tool, %{"name" => "world"})
    end

    test "calls MFA handler with input args" do
      assert {:ok, %Tool{} = tool} = Tool.new(@valid_tool_params)
      assert {:ok, "Hello world"} = Tool.invoke(tool, %{"name" => "world"})
    end

    test "returns error if args dont match schema" do
      assert {:ok, %Tool{} = tool} = Tool.new(@valid_tool_params)
      assert {:error, error} = Tool.invoke(tool, %{"foo" => "bar"})
      assert error =~ ~r/required properties are missing/i
    end

    test "returns error if handler raises" do
      assert {:ok, %Tool{} = tool} = Tool.new(Map.put(@valid_tool_params, :handler, fn _ -> raise "call failed" end))
      assert {:error, error} = Tool.invoke(tool, %{"name" => "world"})
      assert error =~ ~r/call failed/i
    end
  end

  describe "to_map/1" do
    test "converts custom tool to map" do
      assert {:ok, %Tool{} = tool} = Tool.new(@valid_tool_params)
      assert map = Tool.to_map(tool)
      assert map.type == "custom"
      assert map.name == @valid_tool_params.name
      assert map.description == @valid_tool_params.description
      assert %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}} = map.input_schema
    end

    test "converts client and server tools to map with extra config" do
      for type <- [:client, :server] do
        assert {:ok, %Tool{} = tool} = Tool.new(type: type, name: "test", config: %{type: "foobar"})
        assert map = Tool.to_map(tool)
        assert map.type == "foobar"
        assert map.name == "test"
      end
    end
  end

  describe "Module-based tools" do
    defmodule SimpleTestTool do
      use Anthropix.Tool

      name "simple_test_tool"
      description "A simple test tool"
      input_schema do
        map(properties: %{
          "input" => {:string, description: "Input value"}
        })
      end

      @impl true
      def call(%{"input" => input}, _config) do
        "Processed: #{input}"
      end
    end

    defmodule ConfigTestTool do
      use Anthropix.Tool

      name "config_test_tool"
      input_schema do
        map(properties: %{
          "action" => {:string, enum: ["read", "write"], description: "Action to perform"}
        })
      end

      @impl true
      def init(opts) do
        case Keyword.fetch(opts, :api_key) do
          {:ok, api_key} when is_binary(api_key) and api_key != "" ->
            {:ok, %{api_key: api_key, extra: Keyword.get(opts, :extra, "default")}}
          _ ->
            {:error, "Missing or invalid api_key"}
        end
      end

      @impl true
      def call(%{"action" => action}, %{api_key: api_key, extra: extra}) do
        "#{action} with key: #{api_key}, extra: #{extra}"
      end
    end

    test "creates a tool from a simple module" do
      assert {:ok, tool} = SimpleTestTool.new()
      assert tool.name == "simple_test_tool"
      assert tool.description == "A simple test tool"
      assert %Xema{} = tool.input_schema
      assert is_function(tool.handler, 1)

      # Test that the handler calls the module's call/2 function
      assert {:ok, "Processed: test"} = Tool.invoke(tool, %{"input" => "test"})
    end

    test "handles configuration through init callback" do
      # Successful initialization
      assert {:ok, tool} = ConfigTestTool.new(api_key: "secret123", extra: "custom")
      assert {:ok, result} = Tool.invoke(tool, %{"action" => "read"})
      assert result == "read with key: secret123, extra: custom"

      # Init with just required options (extra gets default)
      assert {:ok, tool} = ConfigTestTool.new(api_key: "key456")
      assert {:ok, result} = Tool.invoke(tool, %{"action" => "write"})
      assert result == "write with key: key456, extra: default"

      # Failed initialization
      assert {:error, "Missing or invalid api_key"} = ConfigTestTool.new()
      assert {:error, "Missing or invalid api_key"} = ConfigTestTool.new(api_key: "")
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
