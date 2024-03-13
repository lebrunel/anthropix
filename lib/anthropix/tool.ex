defmodule Anthropix.Tool do
  @moduledoc """
  The `Tool` module allows you to let Claude call functions in your application.

  The `t:Anthropix.Tool.t/0` struct wraps around any function in your
  application - referenced functions, anonymous functions, or MFA style
  functions (`{module(), atom(), list(term())}`).

  Remember, Clause is a language model, so all tools and parameters should be
  given clear descriptions to help Claude undertand how to call your functions
  correctly.

  `new/1` will validate that the wrapped function exists and has the correct
  arity.

  ## Example

  ```elixir
  ticker_tool = Tool.new([
    name: "get_ticker_symbol",
    description: "Gets the stock ticker symbol for a company searched by name. Returns str: The ticker symbol for the company stock. Raises TickerNotFound: if no matching ticker symbol is found.",
    params: [
      %{name: "company_name", description: "The name of the company.", type: "string"}
    ],
    function: &MyApp.get_ticker_symbol/1
  ])

  price_tool = Tool.new([
    name: "get_current_stock_price",
    description: "Gets the current stock price for a company. Returns float: The current stock price. Raises ValueError: if the input symbol is invalid/unknown.",
    params: [
      %{name: "symbol", description: "The stock symbol of the company to get the price for.", type: "string"}
    ],
    function: {MyApp, :get_current_stock_price, ["other", "args"]}
  ])
  ```

  Note that when the MFA style is used, the list of arguments in the MFA tuple
  are treated as extra arguments positioned **after** the arguments defined in
  the tool params. Using the `price_tool` example above, the following function
  should exist:

  ```elixir
  defmodule MyApp do
    def get_current_stock_price(symbol, other, args) do
      # ...
    end
  end
  ```

  For a full example of function calling with Claude, see `Anthropix.Agent`.

  ## Error handling

  When used with `Anthropix.Agent`, when an exception is raised by the tool,
  the name of the exception is passed back to Claude. It is therefore
  recommended to describe your errors in the tool description.

  ```elixir
  case get_current_stock_price(ticker) do
    nil -> raise ValueError, "stock not found"
    price -> price
  end
  ```
  """
  use Anthropix.Schemas

  defstruct name: nil,
            description: nil,
            params: [],
            function: nil

  @typedoc "Tool struct"
  @type t() :: %__MODULE__{
    name: String.t(),
    description: String.t(),
    params: list(param()),
    function: function() | {atom(), atom(), list()}
  }

  @typedoc "Tool parameter"
  @type param() :: %{
    name: String.t(),
    description: String.t(),
    type: String.t(),
  }

  schema :param, [
    name: [
      type: :string,
      required: true,
      doc: "Parameter name."
    ],
    description: [
      type: :string,
      required: true,
      doc: "A plaintext explanation of what the function"
    ],
    type: [
      type: :string,
      required: true,
      doc: "todo"
    ]
  ]

  schema :tool, [
    name: [
      type: :string,
      required: true,
      doc: "The function name."
    ],
    description: [
      type: :string,
      required: true,
      doc: "A plaintext explanation of what the function does, including return value and type."
    ],
    params: [
      type: {:list, {:map, schema(:param).schema}},
      required: true,
      doc: "The expected parameters, their types, and descriptions."
    ],
    function: [
      type: :any,
      required: true,
      doc: "The tool function.",
      type_spec: quote(do: fun() | {module(), atom(), list()})
    ]
  ]

  @doc """
  Creates a new Tool struct from the given parameters.

  ## Options

  #{doc(:tool)}

  ## Parameter structure

  Each parameter is a map with the following fields:

  #{doc(:param)}

  See the example as the [top of this page](#module-example).
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    opts
    |> NimbleOptions.validate!(schema(:tool))
    |> validate_function!()

    struct(__MODULE__, opts)
  end

  # Validates the arity of the wrapped function.
  @spec validate_function!(keyword()) :: :ok
  defp validate_function!(opts) do
    params = Keyword.get(opts, :params)
    fun = Keyword.get(opts, :function)

    bool = case fun do
      fun when is_function(fun) ->
        expected = length(params)
        if match?({:arity, ^expected}, :erlang.fun_info(fun, :arity)),
          do: true,
          else: false

      {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
        expected = length(params) + length(args)
        if function_exported?(mod, fun, expected),
          do: true,
          else: false

      _ -> false
    end

    unless bool do
      raise %NimbleOptions.ValidationError{
        key: :function,
        value: fun,
        message: "Incorrect function arity for parameters"
      }
    end
    :ok
  end

end
