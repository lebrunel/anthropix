defmodule Anthropix.FilesTest do
  use ExUnit.Case, async: true
  alias Anthropix.{APIError, Files}
  alias Anthropix.Mock2, as: Mock

  describe "create/2 mocked" do
    test "creates a file from a filepath only" do
      client = Anthropix.init(plug: Mock.respond("files.create.json"))
      assert {:ok, file} = Files.create(client, "test/data/file.json")
      assert valid_file?(file)
    end

    test "creates a file from params" do
      client = Anthropix.init(plug: Mock.respond("files.create.json"))
      assert {:ok, file} = Files.create(client, %{
        filename: "file.json",
        mime_type: "application/json",
        data: "{\"foo\":\"bar\"}"
      })
      assert valid_file?(file)
    end
  end

  describe "list/2 mocked" do
    test "list all uploaded files" do
      client = Anthropix.init(plug: Mock.respond("files.list.json"))
      assert {:ok, res} = Files.list(client)

      assert is_list(res.data)
      assert is_binary(res.first_id)
      assert is_binary(res.last_id)
      assert is_boolean(res.has_more)
    end
  end

  describe "show/2 mocked" do
    test "shows the file metadata" do
      client = Anthropix.init(plug: Mock.respond("files.show.json"))
      assert {:ok, file} = Files.show(client, "file_011CQKTmtTmZ8Y8uG5WzNSks")
      assert valid_file?(file)
    end

    test "returns 404 for unknown file id" do
      client = Anthropix.init(plug: Mock.respond(404))
      assert {:error, %APIError{status: 404, type: "not_found"}} = Files.show(client, "invalid_id")
    end
  end

  describe "download/2 mocked" do
    @tag :skip
    test "returns the content of a downloadable file" do
    end

    test "returns error for non downloadable file" do
      client = Anthropix.init(plug: Mock.respond(400))
      assert {:error, %APIError{status: 400}} = Files.download(client, "file_011CQKTmtTmZ8Y8uG5WzNSks")
    end

    test "returns 404 for unknown file id" do
      client = Anthropix.init(plug: Mock.respond(404))
      assert {:error, %APIError{status: 404, type: "not_found"}} = Files.download(client, "invalid_id")
    end
  end

  describe "delete/2 mocked" do
    test "deletes the file" do
      client = Anthropix.init(plug: Mock.respond("files.delete.json"))
      assert {:ok, file} = Files.delete(client, "file_011CQKTmtTmZ8Y8uG5WzNSks")
      assert file.type == "file_deleted"
      assert file.id == "file_011CQKTmtTmZ8Y8uG5WzNSks"
    end

    test "returns 404 for unknown file id" do
      client = Anthropix.init(plug: Mock.respond(404))
      assert {:error, %APIError{status: 404, type: "not_found"}} = Files.show(client, "invalid_id")
    end
  end

  @spec valid_file?(term()) :: :ok
  defp valid_file?(file) do
    assert is_binary(file.id)
    assert file.type == "file"
    assert file.filename == "file.json"
    assert file.mime_type == "application/json"
    assert is_integer(file.size_bytes)
    assert match?(%DateTime{}, file.created_at)
    assert match?(%Req.Response{}, file.raw)
    :ok
  end
end
