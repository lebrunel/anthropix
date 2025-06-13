defmodule Anthropix.Util.XemaHelpersTest do
  use ExUnit.Case
  alias Anthropix.Util.XemaHelpers

  describe "xema_to_map/1" do
    test "converts nil schema to null type JSON schema" do
      schema = Xema.new(nil)
      json_schema = XemaHelpers.xema_to_map(schema)

      assert json_schema == %{"type" => "null"}
    end

    test "converts string schema with description" do
      schema = Xema.new({:string, description: "test"})
      json_schema = XemaHelpers.xema_to_map(schema)

      assert json_schema == %{
        "type" => "string",
        "description" => "test"
      }
    end

    test "converts list to array type JSON schema" do
      schema = Xema.new({:list, items: :string, description: "test"})
      json_schema = XemaHelpers.xema_to_map(schema)

      assert json_schema == %{
        "type" => "array",
        "items" => %{"type" => "string"},
        "description" => "test"
      }
    end

    test "converts map to object type JSON schema with properties" do
      schema = Xema.new({:map, properties: %{
        foo: {:string, description: "foo field"},
        bar: {:list, description: "bar field"}
      }, required: [:foo]})

      json_schema = XemaHelpers.xema_to_map(schema)

      assert json_schema == %{
        "type" => "object",
        "properties" => %{
          "foo" => %{
            "type" => "string",
            "description" => "foo field"
          },
          "bar" => %{
            "type" => "array",
            "description" => "bar field"
          }
        },
        "required" => ["foo"]
      }
    end

    test "handles enums correctly" do
      schema = Xema.new({:string, enum: ["red", "green", "blue"]})
      json_schema = XemaHelpers.xema_to_map(schema)

      assert json_schema == %{
        "type" => "string",
        "enum" => ["red", "green", "blue"]
      }
    end

    test "handles regex patterns" do
      schema = Xema.new({:string, pattern: ~r/^[a-z]+$/})
      json_schema = XemaHelpers.xema_to_map(schema)

      assert json_schema == %{
        "type" => "string",
        "pattern" => "^[a-z]+$"
      }
    end

    test "handles numeric constraints" do
      schema = Xema.new({:integer, minimum: 5, maximum: 10, multiple_of: 2})
      json_schema = XemaHelpers.xema_to_map(schema)

      assert json_schema == %{
        "type" => "integer",
        "minimum" => 5,
        "maximum" => 10,
        "multipleOf" => 2
      }
    end

    test "handles nested schemas with allOf, anyOf, oneOf" do
      schema = Xema.new(any_of: [
        {:string, min_length: 3},
        {:integer, minimum: 10}
      ])

      json_schema = XemaHelpers.xema_to_map(schema)

      assert json_schema == %{
        "type" => "any",
        "anyOf" => [
          %{"type" => "string", "minLength" => 3},
          %{"type" => "integer", "minimum" => 10}
        ]
      }
    end

    test "handles schema references" do
      schema = Xema.new({:map,
        definitions: %{
          a: :string,
        },
        properties: %{
          b: {:ref, "#/definitions/a"},
          c: {:ref, "#/properties/b"}
        }
      })
      json_schema = XemaHelpers.xema_to_map(schema)

      assert json_schema == %{
        "type" => "object",
        "$defs" => %{
          "a" => %{"type" => "string"}
        },
        "properties" => %{
          "b" => %{"type" => "string"},
          "c" => %{"type" => "string"}
        }
      }
    end

    test "handles complex nested schema with multiple types" do
      user_schema = Xema.new({:map,
        properties: %{
          id: :integer,
          name: {:string, min_length: 1},
          email: {:string, format: :email},
          tags: {:list, items: :string},
          address: {:map,
            properties: %{
              street: :string,
              city: :string,
              country: :string
            },
            required: [:city, :country]
          }
        },
        required: [:id, :name, :email],
        additional_properties: false
      })

      json_schema = XemaHelpers.xema_to_map(user_schema)

      assert json_schema["type"] == "object"
      assert json_schema["additionalProperties"] == "false"
      assert json_schema["required"] == ["id", "name", "email"]
      assert json_schema["properties"]["id"]["type"] == "integer"
      assert json_schema["properties"]["name"]["type"] == "string"
      assert json_schema["properties"]["name"]["minLength"] == 1
      assert json_schema["properties"]["address"]["type"] == "object"
      assert json_schema["properties"]["address"]["required"] == ["city", "country"]
      assert json_schema["properties"]["tags"]["type"] == "array"
      assert json_schema["properties"]["tags"]["items"]["type"] == "string"
    end
  end
end
