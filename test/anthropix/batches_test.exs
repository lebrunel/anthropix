defmodule Anthropix.BatchesTest do
  use ExUnit.Case, async: true
  alias Anthropix.{APIError, Batches, StreamingResponse}
  alias Anthropix.Mock2, as: Mock

  describe "create/2" do
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

  describe "results/2" do
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

    #test "with stream: true, returns a lazy enumerable" do
    #  client = Mock.client(& Mock.respond(&1, :batch_results))
    #  assert {:ok, stream} = Batch.results(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R", stream: true)
    #
    #  assert is_function(stream, 2)
    #  assert Enum.to_list(stream) |> length() == 2
    #end
    #
    #test "with stream: pid, returns a task and sends messages to pid" do
    #  {:ok, pid} = Anthropix.StreamCatcher.start_link()
    #  client = Mock.client(& Mock.respond(&1, :batch_results))
    #  assert {:ok, task} = Batch.results(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R", stream: pid)
    #
    #  assert match?(%Task{}, task)
    #  assert {:ok, res} = Task.await(task)
    #  assert is_list(res)
    #  assert length(res) == 2
    #  assert Anthropix.StreamCatcher.get_state(pid) |> length() == 2
    #  GenServer.stop(pid)
    #end
  end

  describe "stream_results/2" do
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

  describe "list/2" do
    test "list all message batches" do
      client = Anthropix.init(plug: Mock.respond("batches.list.json"))
      assert {:ok, res} = Batches.list(client)

      assert is_list(res.data)
      assert is_binary(res.first_id)
      assert is_binary(res.last_id)
      assert is_boolean(res.has_more)
    end
  end

  describe "show/2" do
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
end
