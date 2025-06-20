defmodule Anthropix.BatchesTest do
  use ExUnit.Case, async: true
  alias Anthropix.{APIError, Batches, StreamingResponse}
  alias Anthropix.Mock2, as: Mock

  describe "create/2 mocked" do
    test "creates a message batch from a flat list or params map" do
      client = Anthropix.init(plug: Mock.respond("batches.create.json"))
      requests = [
        %{custom_id: "foo", params: %{model: "claude-3-haiku-20240307", messages: [%{role: "user", content: "Why is the sky blue?"}]}},
        %{custom_id: "bar", params: %{model: "claude-3-haiku-20240307", messages: [%{role: "user", content: "Why is the sea blue?"}]}}
      ]

      for params <- [requests, %{requests: requests}] do
        assert {:ok, res} = Batches.create(client, params)
        assert res.id == "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R"
        assert res.type == "message_batch"
        assert res.processing_status == "in_progress"
        assert get_in(res.request_counts.processing) == 2
      end
    end
  end

  describe "results/2 mocked" do
    test "downloads batch results by ID" do
      client = Anthropix.init(plug: Mock.respond("batches.results.jsonl", content_type: "application/jsonl",  headers: [
        {"content-disposition", "attachment; filename=\"results.jsonl\""}
      ]))
      assert {:ok, res} = Batches.results(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R")

      assert is_list(res)
      assert length(res) == 2
      assert "foo" in Enum.map(res, & &1.custom_id)
      assert "bar" in Enum.map(res, & &1.custom_id)
      assert Enum.all?(res, & is_map(&1.result))
    end

    test "downloads batch results by URL" do
      client = Anthropix.init(plug: Mock.respond("batches.results.jsonl", content_type: "application/jsonl", headers: [
        {"content-disposition", "attachment; filename=\"results.jsonl\""}
      ]))
      assert {:ok, res} = Batches.results(client, "https://api.anthropic.com/v1/messages/batches/msgbatch_01DJuZbTFXpGRhqTdqFH1P2R/results")

      assert is_list(res)
      assert length(res) == 2
      assert "foo" in Enum.map(res, & &1.custom_id)
      assert "bar" in Enum.map(res, & &1.custom_id)
      assert Enum.all?(res, & is_map(&1.result))
    end

    test "returns 404 for unknown batch id" do
      client = Anthropix.init(plug: Mock.respond(404))
      assert {:error, %APIError{status: 404, type: "not_found"}} = Batches.results(client, "invalid_id")
    end
  end

  describe "stream_results/2 mocked" do
    test "returns a StreamingResponse" do
      client = Anthropix.init(plug: Mock.respond("batches.results.jsonl", content_type: "application/jsonl",  headers: [
        {"content-disposition", "attachment; filename=\"results.jsonl\""}
      ]))
      assert {:ok, res} =
        Batches.stream_results(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R")
        |> StreamingResponse.run()

      assert is_list(res)
      assert length(res) == 2
      assert Enum.all?(res, & is_map(&1.result))
    end

    test "downloads batch results by URL" do
      client = Anthropix.init(plug: Mock.respond("batches.results.jsonl", content_type: "application/jsonl", headers: [
        {"content-disposition", "attachment; filename=\"results.jsonl\""}
      ]))
      assert {:ok, res} =
        Batches.stream_results(client, "https://api.anthropic.com/v1/messages/batches/msgbatch_01DJuZbTFXpGRhqTdqFH1P2R/results")
        |> StreamingResponse.run()

      assert is_list(res)
      assert length(res) == 2
      assert Enum.all?(res, & is_map(&1.result))
    end
  end

  describe "list/2 mocked" do
    test "list all message batches" do
      client = Anthropix.init(plug: Mock.respond("batches.list.json"))
      assert {:ok, res} = Batches.list(client)

      assert is_list(res.data)
      assert is_binary(res.first_id)
      assert is_binary(res.last_id)
      assert is_boolean(res.has_more)
    end
  end

  describe "show/2 mocked" do
    test "shows the batch status" do
      client = Anthropix.init(plug: Mock.respond("batches.show.json"))
      assert {:ok, res} = Batches.show(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R")

      assert res.id == "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R"
      assert res.type == "message_batch"
      assert res.processing_status == "ended"
      assert get_in(res.request_counts.succeeded) == 2
    end

    test "returns 404 for unknown batch id" do
      client = Anthropix.init(plug: Mock.respond(404))
      assert {:error, %APIError{status: 404, type: "not_found"}} = Batches.show(client, "invalid_id")
    end
  end

  describe "cancel/2 mocked" do
    @tag :skip
    test "deletes the batch" do
    end

    test "returns 404 for unknown file id" do
      client = Anthropix.init(plug: Mock.respond(404))
      assert {:error, %APIError{status: 404, type: "not_found"}} = Batches.cancel(client, "invalid_id")
    end
  end

  describe "delete/2 mocked" do
    test "deletes the batch" do
      client = Anthropix.init(plug: Mock.respond("batches.delete.json"))
      assert {:ok, file} = Batches.delete(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R")
      assert file.type == "message_batch_deleted"
      assert file.id == "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R"
    end

    test "returns 404 for unknown file id" do
      client = Anthropix.init(plug: Mock.respond(404))
      assert {:error, %APIError{status: 404, type: "not_found"}} = Batches.show(client, "invalid_id")
    end
  end
end
