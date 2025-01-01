defmodule Anthropix.BatchTest do
  use ExUnit.Case, async: true
  alias Anthropix.Batch
  alias Anthropix.{APIError, Mock}

  describe "create/2" do
    test "generates a message batch" do
      client = Mock.client(& Mock.respond(&1, :batch_create))
      assert {:ok, res} = Batch.create(client, requests: [%{
        custom_id: "foo",
        params: %{
          model: "claude-3-haiku-20240307",
          messages: [
            %{role: "user", content: "Why is the sky blue?"},
          ]
        }
      }, %{
        custom_id: "bar",
        params: %{
          model: "claude-3-haiku-20240307",
          messages: [
            %{role: "user", content: "Why is the sea blue?"},
          ]
        }
      }])

      assert res["id"] == "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R"
      assert res["type"] == "message_batch"
      assert res["processing_status"] == "in_progress"
      assert get_in(res, ["request_counts", "processing"]) == 2
    end
  end

  describe "list/2" do
    test "list all message batches" do
      client = Mock.client(& Mock.respond(&1, :batch_list))
      assert {:ok, res} = Batch.list(client)

      assert is_list(res["data"])
      assert is_binary(res["first_id"])
      assert is_binary(res["last_id"])
      assert is_boolean(res["has_more"])
    end
  end

  describe "show/2" do
    test "shows the batch status" do
      client = Mock.client(& Mock.respond(&1, :batch_show))
      assert {:ok, res} = Batch.show(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R")

      assert res["id"] == "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R"
      assert res["type"] == "message_batch"
      assert res["processing_status"] == "ended"
      assert get_in(res, ["request_counts", "succeeded"]) == 2
    end

    test "returns 404 for unknown batch id" do
      client = Mock.client(& Mock.respond(&1, 404))
      assert {:error, %APIError{status: 404, type: "not_found"}} = Batch.show(client, "invalid_id")
    end
  end

  describe "results/2" do
    test "downloads batch results by ID" do
      client = Mock.client(& Mock.respond(&1, :batch_results))
      assert {:ok, res} = Batch.results(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R")

      assert is_list(res)
      assert length(res) == 2
      assert "foo" in Enum.map(res, & &1["custom_id"])
      assert "bar" in Enum.map(res, & &1["custom_id"])
      assert Enum.all?(res, & is_map(&1["result"]))
    end

    test "downloads batch results by URL" do
      client = Mock.client(& Mock.respond(&1, :batch_results))
      assert {:ok, res} = Batch.results(client, "https://api.anthropic.com/v1/messages/batches/msgbatch_01DJuZbTFXpGRhqTdqFH1P2R/results")

      assert is_list(res)
      assert length(res) == 2
      assert "foo" in Enum.map(res, & &1["custom_id"])
      assert "bar" in Enum.map(res, & &1["custom_id"])
      assert Enum.all?(res, & is_map(&1["result"]))
    end

    test "downloads batch results by batch status map" do
      client = Mock.client(& Mock.respond(&1, :batch_show))
      assert {:ok, res} = Batch.show(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R")
      client = Mock.client(& Mock.respond(&1, :batch_results))
      assert {:ok, res} = Batch.results(client, res)

      assert is_list(res)
      assert length(res) == 2
      assert "foo" in Enum.map(res, & &1["custom_id"])
      assert "bar" in Enum.map(res, & &1["custom_id"])
      assert Enum.all?(res, & is_map(&1["result"]))
    end

    test "returns 404 for unknown batch id" do
      client = Mock.client(& Mock.respond(&1, 404))
      assert {:error, %APIError{status: 404, type: "not_found"}} = Batch.results(client, "invalid_id")
    end

    test "with stream: true, returns a lazy enumerable" do
      client = Mock.client(& Mock.respond(&1, :batch_results))
      assert {:ok, stream} = Batch.results(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R", stream: true)

      assert is_function(stream, 2)
      assert Enum.to_list(stream) |> length() == 2
    end

    test "with stream: pid, returns a task and sends messages to pid" do
      {:ok, pid} = Anthropix.StreamCatcher.start_link()
      client = Mock.client(& Mock.respond(&1, :batch_results))
      assert {:ok, task} = Batch.results(client, "msgbatch_01DJuZbTFXpGRhqTdqFH1P2R", stream: pid)

      assert match?(%Task{}, task)
      assert {:ok, res} = Task.await(task)
      assert is_list(res)
      assert length(res) == 2
      assert Anthropix.StreamCatcher.get_state(pid) |> length() == 2
      GenServer.stop(pid)
    end
  end
end
