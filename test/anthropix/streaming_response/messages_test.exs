defmodule Anthropix.StreamingResponse.MessagesTest do
  use ExUnit.Case, async: true
  alias Anthropix.StreamingResponse.Messages
  alias Anthropix.APIError

  describe "handle_buffer/1" do
    test "handles empty buffer" do
      assert {[], ""} = Messages.handle_buffer("")
    end

    test "handles buffer with only whitespace" do
      buffer = "   \n\r\n  "
      assert {[], ^buffer} = Messages.handle_buffer(buffer)
    end

    test "handles buffer with partial SSE match - truncated in event type" do
      buffer = "event: mess"
      assert {[], ^buffer} = Messages.handle_buffer(buffer)
    end

    test "handles buffer with partial SSE match - truncated in data" do
      buffer = """
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_123"
      """

      assert {[], ^buffer} = Messages.handle_buffer(buffer)
    end

    test "handles buffer with one complete SSE match" do
      buffer = """
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_123"}}
      """

      assert {events, remaining} = Messages.handle_buffer(buffer)
      assert [{:data, event}] = events
      assert event["type"] == "message_start"
      assert event["message"]["id"] == "msg_123"
      assert remaining == ""
    end

    test "handles buffer with one complete match and partial match" do
      buffer = """
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_123"}}
      event: content_block_start
      data: {"type": "content_block_start", "index": 0
      """

      assert {events, remaining} = Messages.handle_buffer(buffer)
      assert [{:data, event}] = events
      assert event["type"] == "message_start"

      # Should preserve the partial match for next processing
      assert remaining =~ "event: content_block_start"
      assert remaining =~ ~r/"index": 0/
    end

    test "handles buffer with multiple complete SSE matches" do
      buffer = """
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_123"}}
      event: content_block_start
      data: {"type": "content_block_start", "index": 0}
      event: content_block_delta
      data: {"type": "content_block_delta", "delta": {"text": "Hello"}}
      """

      assert {events, remaining} = Messages.handle_buffer(buffer)
      assert [{:data, event1}, {:data, event2}, {:data, event3}] = events
      assert event1["type"] == "message_start"
      assert event2["type"] == "content_block_start"
      assert event3["type"] == "content_block_delta"
      assert remaining == ""
    end

    test "handles buffer with error event" do
      buffer = """
      event: error
      data: {"type": "error", "error": {"type": "overloaded_error", "message": "Something went wrong"}}
      """

      {events, remaining} = Messages.handle_buffer(buffer)

      assert length(events) == 1
      assert [{:error, %APIError{} = error}] = events
      assert error.message == "Something went wrong"
      assert remaining == ""
    end

    test "handles buffer with mixed data and error events" do
      buffer = """
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_123"}}
      event: error
      data: {"type": "error", "error": {"type": "overloaded_error", "message": "API limit exceeded"}}
      event: content_block_start
      data: {"type": "content_block_start", "index": 0}
      """

      assert {events, remaining} = Messages.handle_buffer(buffer)
      assert [{:data, data1}, {:error, %APIError{} = error}, {:data, data2}] = events
      assert data1["type"] == "message_start"
      assert data2["type"] == "content_block_start"
      assert error.message == "API limit exceeded"
      assert remaining == ""
    end

    test "filters out unknown event types" do
      buffer = """
      event: unknown_event
      data: {"type": "unknown_event", "data": "should be ignored"}
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_123"}}
      event: another_unknown
      data: {"type": "another_unknown", "data": "also ignored"}
      """

      assert {events, remaining} = Messages.handle_buffer(buffer)
      assert [{:data, event}] = events
      assert event["type"] == "message_start"
      assert remaining == ""
    end

    test "handles extra whitespace in event and data fields" do
      buffer = """
      event:   message_start
      data:   {"type": "message_start", "message": {"id": "msg_123"}}


      """

      assert {events, remaining} = Messages.handle_buffer(buffer)
      assert [{:data, event}] = events
      assert event["type"] == "message_start"
      assert remaining == ""
    end

    test "handles nested JSON objects in data" do
      buffer = """
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_123", "metadata": {"nested": {"deeply": "value"}}}}
      """

      assert {events, remaining} = Messages.handle_buffer(buffer)
      assert [{:data, event}] = events
      assert event["message"]["metadata"]["nested"]["deeply"] == "value"
      assert remaining == ""
    end

    test "handles all supported event types" do
      event_types = [
        "message_start",
        "content_block_start",
        "content_block_delta",
        "content_block_stop",
        "message_delta",
        "message_stop"
      ]

      buffer =
        event_types
        |> Enum.map(& "event: #{&1}\ndata: {\"type\": \"#{&1}\"}\n")
        |> Enum.join("\n")

      assert {events, remaining} = Messages.handle_buffer(buffer)
      assert length(events) == 6
      assert Enum.all?(events, & match?({:data, _}, &1))
      assert Enum.all?(events, fn {:data, event} -> event["type"] in event_types end)
      assert remaining == ""
    end

    test "raises on invalid JSON in data field" do
      buffer = """
      event: message_start
      data: {invalid json here}
      """

      assert_raise Jason.DecodeError, fn ->
        Messages.handle_buffer(buffer)
      end
    end

    test "handles buffer with trailing newlines and whitespace" do
      buffer = """
      event: message_start
      data: {"type": "message_start"}


      """

      assert {events, remaining} = Messages.handle_buffer(buffer)
      assert [{:data, event}] = events
      assert event["type"] == "message_start"
      assert remaining == ""
    end

    test "preserves partial match with preceding complete matches" do
      buffer = """
      event: message_start
      data: {"type": "message_start"}
      event: content_block_start
      data: {"type": "content_block_start"}
      event: message_delta
      data: {"type": "message_delta", "delta": {"text": "partial
      """

      assert {events, remaining} = Messages.handle_buffer(buffer)
      assert [{:data, event1}, {:data, event2}] = events
      assert event1["type"] == "message_start"
      assert event2["type"] == "content_block_start"

      # Should preserve the incomplete event for next chunk
      assert remaining =~ "event: message_delta"
      assert remaining =~ "partial"
    end

    test "handles full example" do
      buffer = """
      event: message_start
      data: {"type":"message_start","message":{"id":"msg_01W5Fks2H3MNPG9Rf2tw3azc","type":"message","role":"assistant","model":"claude-3-5-haiku-20241022","content":[],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":350,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1,"service_tier":"standard"}}}


      event: content_block_start
      data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}


      event: ping
      data: {"type": "ping"}


      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Let"}}


      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" me help"}}


      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" you find John Smith's"}}


      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" contact details."}}


      event: content_block_stop
      data: {"type":"content_block_stop","index":0}


      event: content_block_start
      data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_01MTPeDLMo26pyukmgXfcrvx","name":"get_contact_details","input":{}}}


      event: content_block_delta
      data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":""}}


      event: content_block_delta
      data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\\""}}


      event: content_block_delta
      data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"name\\": \\""}}


      event: content_block_delta
      data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"John Smi"}}


      event: content_block_delta
      data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"th\\"}"}}


      event: content_block_stop
      data: {"type":"content_block_stop","index":1}


      event: message_delta
      data: {"type":"message_delta","delta":{"stop_reason":"tool_use","stop_sequence":null},"usage":{"output_tokens":68}}


      event: message_stop
      data: {"type":"message_stop"}


      """

      assert {events, remaining} = Messages.handle_buffer(buffer)
      assert length(events) == 16
      assert remaining == ""
    end
  end
end
