defmodule Anthropix.Utils.MapUtilsTest do
  use ExUnit.Case, async: true
  alias Anthropix.Utils.MapUtils

  setup_all do
    # Create known atoms
    :name
    :age
    :address
    :street
    :city

    :ok
  end

  describe "safe_atomize_keys/1" do
    test "converts string keys to atoms when atoms exist" do
      input = %{"name" => "John", "age" => 30}
      expected = %{name: "John", age: 30}

      assert MapUtils.safe_atomize_keys(input) == expected
    end

    test "preserves existing atom keys" do
      input = %{:name => "John", :age => 30}
      expected = %{name: "John", age: 30}

      assert MapUtils.safe_atomize_keys(input) == expected
    end

    test "handles mixed string and atom keys" do
      input = %{"name" => "John", :age => 30}
      expected = %{name: "John", age: 30}

      assert MapUtils.safe_atomize_keys(input) == expected
    end

    test "removes string keys that don't correspond to existing atoms" do
      input = %{"name" => "John", "unknown_key" => "should be removed", "age" => 30}
      expected = %{name: "John", age: 30}

      assert MapUtils.safe_atomize_keys(input) == expected
    end

    test "handles nested maps" do
      input = %{"name" => "John", "address" => %{
        "street" => "123 Main St",
        "city" => "Boston",
        "unknown_field" => "removed"
      }}

      expected = %{name: "John", address: %{
        street: "123 Main St",
        city: "Boston"
      }}

      assert MapUtils.safe_atomize_keys(input) == expected
    end

    test "handles deeply nested maps" do
      input = %{
        :config => %{
          :settings => %{
            :nested => %{
              "name" => "deep value",
              "unknown_field" => "removed"
            }
          }
        }
      }

      expected = %{
        config: %{
          settings: %{
            nested: %{
              name: "deep value"
            }
          }
        }
      }

      assert MapUtils.safe_atomize_keys(input) == expected
    end

    test "handles lists of maps" do
      input = %{:tags => [
        %{"name" => "tag1"},
        %{"name" => "tag2", "unknown_field" => "removed"}
      ]}

      expected = %{tags: [
        %{name: "tag1"},
        %{name: "tag2"}
      ]}

      assert MapUtils.safe_atomize_keys(input) == expected
    end

    test "handles nested lists and maps" do
      input = [
        %{"name" => "John", :tags => [
          %{"name" => 1, "unknown_field" => "removed"},
          %{"name" => 2}
        ]},
        %{"name" => "Jane", "age" => 25}
      ]

      expected = [
        %{name: "John", tags: [%{name: 1}, %{name: 2}]},
        %{name: "Jane", age: 25}
      ]

      assert MapUtils.safe_atomize_keys(input) == expected
    end

    test "handles maps with only unknown string keys" do
      input = %{
        "completely_unknown_key_xyz" => "value1",
        "another_unknown_key_abc" => "value2"
      }

      assert MapUtils.safe_atomize_keys(input) == %{}
    end

    test "handles empty maps and lists" do
      assert MapUtils.safe_atomize_keys(%{}) == %{}
      assert MapUtils.safe_atomize_keys([]) == []
    end

    test "preserves non-string, non-atom keys" do
      input = %{
        "name" => "John",
        123 => "numeric key",
        {:tuple, :key} => "tuple key",
        "age" => 30
      }

      expected = %{
        :name => "John",
        123 => "numeric key",
        {:tuple, :key} => "tuple key",
        :age => 30
      }

      assert MapUtils.safe_atomize_keys(input) == expected
    end

    test "handles primitive values (non-map, non-list)" do
      assert MapUtils.safe_atomize_keys("string") == "string"
      assert MapUtils.safe_atomize_keys(42) == 42
      assert MapUtils.safe_atomize_keys(:atom) == :atom
      assert MapUtils.safe_atomize_keys(nil) == nil
      assert MapUtils.safe_atomize_keys(true) == true
    end

  end
end
