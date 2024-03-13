defmodule Anthropix.AgentTest do
  use ExUnit.Case
  alias Anthropix.{Agent, APIError, Mock, Tool}

  @tickers %{
    "General Motors" => "GM",
  }

  @prices %{
    "GM" => 39.21,
  }

  setup_all do
    ticker_tool = Tool.new([
      name: "get_ticker_symbol",
      description: "Gets the stock ticker symbol for a company searched by name. Returns str: The ticker symbol for the company stock. Raises TickerNotFound: if no matching ticker symbol is found.",
      params: [
        %{name: "company_name", description: "The name of the company.", type: "string"}
      ],
      function: fn name -> @tickers[name] || raise "TickerNotFound" end
    ])

    price_tool = Tool.new([
      name: "get_current_stock_price",
      description: "Gets the current stock price for a company. Returns float: The current stock price. Raises ValueError: if the input symbol is invalid/unknown.",
      params: [
        %{name: "symbol", description: "The stock symbol of the company to get the price for.", type: "string"}
      ],
      function: fn symbol -> @prices[symbol] || raise "ValueError" end
    ])

    {:ok, tools: [ticker_tool, price_tool]}
  end

  describe "chat/2" do
    test "returns agent with result complete", %{tools: tools} do
      agent =
        Mock.client(& Mock.respond(&1, {:agent, :messages}))
        |> Agent.init(tools)

      assert {:ok, agent} = Agent.chat(agent, [
        model: "claude-3-sonnet-20240229",
        system: "Answer like Snoop Dogg.",
        messages: [
          %{role: "user", content: "What is the current stock price of General Motors?"}
        ]
      ])

      assert length(agent.messages) == 5
      assert is_map(agent.result)
      assert is_map(agent.usage)

      expected = "Word, the current stock price for General Motors is $39.21. Representing that big auto money, ya dig? Gotta make them stacks and invest wisely in the motor city players."
      assert ^expected = hd(agent.result["content"]) |> Map.get("text")
    end

    test "returns error when model not found", %{tools: tools} do
      agent =
        Mock.client(& Mock.respond(&1, 404))
        |> Agent.init(tools)

      assert {:error, %APIError{type: "not_found"}} = Agent.chat(agent, [
        model: "claude-3-sonnet-20240229",
        system: "Answer like Snoop Dogg.",
        messages: [
          %{role: "user", content: "What is the current stock price of General Motors?"}
        ]
      ])
    end
  end

end
