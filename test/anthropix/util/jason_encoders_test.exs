defmodule Anthropix.Util.JasonEncodersTest do
  use ExUnit.Case, async: true

  describe "Jason.Encoder, for: Anthropix.Message" do
    test "encodes a Message struct to JSON" do
      {:ok, tool} = Anthropix.Message.new(role: "user", content: [
        %{type: "text", text: "test"},
        %{type: "image", source: %{type: "base64", media_type: "image/png", data: "test"}},
      ])

      assert {:ok, json} = Jason.encode(tool)
      assert is_binary(json)
      assert json =~ ~r/"role":"user"/
      assert json =~ ~r/"content":\[.*\]/
      assert json =~ ~r/"type":"text"/
      assert json =~ ~r/"type":"image"/
    end
  end

  describe "Jason.Encoder, for: Anthropix.Tool" do
    test "encodes a Tool struct to JSON" do
      {:ok, tool} = Anthropix.Tool.new([
        name: "test",
        description: "test tool",
        input_schema: Xema.new({:map, properties: %{input: :string}}),
        handler: fn _params -> "result" end
      ])

      assert {:ok, json} = Jason.encode(tool)
      assert is_binary(json)
      assert json =~ ~r/"type":"custom"/
      assert json =~ ~r/"name":"test"/
      assert json =~ ~r/"description":"test tool"/
      assert json =~ ~r/"input_schema":\{.*\}/
    end
  end

  describe "Jason.Encoder, for: [Xema, Xema.Schema]" do
    setup do
      xema = Xema.new({:map, properties: %{input: :string}, required: [:input]})
      {:ok, xema: xema}
    end

    test "encodes a Xema struct to JSON", %{xema: xema} do
      assert {:ok, json} = Jason.encode(xema)
      assert is_binary(json)
      assert json =~ ~r/"type":"object"/
      assert json =~ ~r/"properties":\{"input":\{"type":"string"\}\}/
      assert json =~ ~r/"required":\["input"\]/
    end

  test "encodes a Xema.Schema struct to JSON", %{xema: xema} do
      assert {:ok, json} = Jason.encode(xema.schema)
      assert is_binary(json)
      assert json =~ ~r/"type":"object"/
      assert json =~ ~r/"properties":\{"input":\{"type":"string"\}\}/
      assert json =~ ~r/"required":\["input"\]/
    end
  end

end
