defmodule Anthropix.Tools.WebSearchTest do
  use ExUnit.Case, async: true
  alias Anthropix.Tools.WebSearch
  alias Anthropix.Tool

  describe "new/1" do
    test "initializes with default config" do
      assert {:ok, %Tool{} = tool} = WebSearch.new()
      assert tool.type == :server
      assert tool.name == "web_search"
      assert tool.config.type == "web_search_20250305"
    end

    test "accepts lists of allowed and blocked domains" do
      assert {:ok, %Tool{} = tool} = WebSearch.new(allowed_domains: ["example.com"], blocked_domains: ["blocked.com"])
      assert tool.config.allowed_domains == ["example.com"]
      assert tool.config.blocked_domains == ["blocked.com"]
    end

    test "accepts max_uses option" do
      assert {:ok, %Tool{} = tool} = WebSearch.new(max_uses: 10)
      assert tool.config.max_uses == 10
    end

    test "accepts user location map" do
      location = %{
        type: "approximate",
        city: "London",
        country: "GB",
        timezone: "Europe/London"
      }
      assert {:ok, %Tool{} = tool} = WebSearch.new(user_location: location)
      assert tool.config.user_location == location
    end
  end

  describe "Tool.to_map/1" do
    test "returns a map representation of the tool" do
      assert {:ok, %Tool{} = tool} = WebSearch.new([
        allowed_domains: ["example.com"],
        blocked_domains: ["blocked.com"],
        max_uses: 10,
        cache_control: %{type: "ephemeral", ttl: "5m"}
      ])
      assert %{
        type: "web_search_20250305",
        name: "web_search",
        allowed_domains: ["example.com"],
        blocked_domains: ["blocked.com"],
        max_uses: 10,
        cache_control: %{type: "ephemeral", ttl: "5m"}
      } = Tool.to_map(tool)
    end
  end

end
