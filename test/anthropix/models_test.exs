defmodule Anthropix.ModelsTest do
  use ExUnit.Case, async: true
  alias Anthropix.{APIError, Models}
  alias Anthropix.Mock2, as: Mock

  describe "list/2 mocked" do
    test "returns a list of models" do
      client = Anthropix.init(plug: Mock.respond("models.list.json"))
      assert {:ok, res} = Models.list(client)

      assert is_list(res.data)
      assert is_binary(res.first_id)
      assert is_binary(res.last_id)
      assert is_boolean(res.has_more)
    end
  end

  describe "show/2 mocked" do
    test "shows the model info" do
      client = Anthropix.init(plug: Mock.respond("models.show.json"))
      assert {:ok, model} = Models.show(client, "claude-opus-4-20250514")
      assert valid_model?(model)
    end

    test "returns 404 for unknown file id" do
      client = Anthropix.init(plug: Mock.respond(404))
      assert {:error, %APIError{status: 404, type: "not_found"}} = Models.show(client, "invalid_id")
    end
  end

  @spec valid_model?(term()) :: :ok
  defp valid_model?(file) do
    assert file.type == "model"
    assert is_binary(file.id)
    assert is_binary(file.display_name)
    assert match?(%DateTime{}, file.created_at)
    assert match?(%Req.Response{}, file.raw)
    :ok
  end
end
