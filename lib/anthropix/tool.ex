defmodule Anthropix.Tool do
  import Peri
  import Anthropix.Util.XemaHelpers, only: [xema_to_map: 1]

  defstruct [:type, :name, :description, :input_schema, :handler, :config]

  @type t() :: %__MODULE__{
    type: :custom | :client | :server,
    name: String.t(),
    description: String.t() | nil,
    input_schema: Xema.t() | map() | nil,
    handler: handler() | {module(), atom(), list()} |  nil,
    config: map()
  }

  @type handler() :: (params :: any() -> result :: any())

  @tool_types [:custom, :client, :server]

  defschema :tool, %{
    type: {{:either, {
      {:enum, @tool_types},
      {{:enum, Enum.map(@tool_types, &Atom.to_string/1)}, {:transform, &String.to_atom/1}},
    }}, {:default, :custom}},
    name: {:required, :string},
    description: :string,
    input_schema: {:cond, &is_custom?/1, {:required, {:custom, &validate_input_schema/1}}, nil},
    handler: {:custom, &validate_handler/1},
    config: {:map, {:default, %{}}}
  }

  # Callbacks

  @callback init(opts :: Enumerable.t()) :: {:ok, config :: map()} | {:error, term()}

  @callback call(params :: any(), config :: map()) :: any()

  # Functions

  @spec new(params :: Enumerable.t()) :: {:ok, t()} | {:error, term()}
  def new(params) when is_map(params) or is_list(params) do
    with {:ok, params} <- tool(params) do
      {:ok, struct(__MODULE__, params)}
    end
  end

  @spec new!(params :: Enumerable.t()) :: t()
  def new!(params) when is_map(params) or is_list(params) do
    struct!(__MODULE__, tool!(params))
  end

  @spec invoke(tool :: t(), params :: any()) :: {:ok, any()} | {:error, binary()}
  def invoke(%__MODULE__{input_schema: schema, handler: handler}, params) when not is_nil(handler) do
    try do
      Xema.validate!(schema, params)
      {:ok, invoke_handler(handler, params)}
    rescue
      error ->
        {:error, Exception.format(:error, error)}
    end
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{type: :custom} = tool) do
    input_schema = case tool.input_schema do
      %Xema{} = xema -> xema_to_map(xema)
      schema -> schema
    end

    tool
    |> Map.take([:type, :name, :description])
    |> Map.update!(:type, &Atom.to_string/1)
    |> Map.put(:input_schema, input_schema)
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  def to_map(%__MODULE__{name: name, config: config}) do
    Map.put(config, :name, name)
  end

  # Macros

  defmacro __using__(opts \\ []) do
    tool_type = Keyword.get(opts, :type, :custom)

    unless tool_type in @tool_types do
      raise CompileError, description: """
      Type must be one of :custom, :client, or :server.
      """
    end

    quote do
      import Anthropix.Tool, only: [name: 1, description: 1, input_schema: 1]
      @behaviour Anthropix.Tool
      @before_compile Anthropix.Tool
      @tool_type unquote(tool_type)

      Module.register_attribute(__MODULE__, :name, [])
      Module.register_attribute(__MODULE__, :description, [])
      Module.register_attribute(__MODULE__, :input_schema, [])

      @impl true
      def init(opts \\ []) do
        {:ok, Enum.into(opts, %{})}
      end

      defoverridable init: 1
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      if is_nil(@name) do
        raise CompileError, description: """
        Tool modules must specify a name. Use the `name/1` macro to set the tool name.
        """
      end

      if @tool_type == :custom and is_nil(@input_schema) do
        raise CompileError, description: """
        Tool modules must specify an input schema. Use the `input_schema/1` macro to set the schema.
        """
      end

      if @tool_type == :server do
        # satisfy the call/2 behaviour
        @impl Anthropix.Tool
        def call(_input, _config), do: nil
      end

      @spec new(opts :: Enumerable.t()) :: {:ok, Anthropix.Tool.t()} | {:error, term()}
      def new(opts \\ []) when is_map(opts) or is_list(opts) do
        with {:ok, config} <- init(opts) do
          Anthropix.Tool.new([
            type: @tool_type,
            name: @name,
            description: @description,
            input_schema: @input_schema,
            handler: & call(&1, config),
            config: config
          ])
        end
      end

      def new!(opts \\ []) when is_map(opts) or is_list(opts) do
        case new(opts) do
          {:ok, tool} -> tool
          {:error, errors} when is_list(errors) -> raise Peri.InvalidSchema, errors
          {:error, error} -> raise error
        end
      end

      defoverridable new: 1
    end
  end

  @spec name(value :: String.t()) :: Macro.t()
  defmacro name(value) do
    quote do: @name unquote(value)
  end

  @spec description(value :: String.t()) :: Macro.t()
  defmacro description(value) do
    quote do: @description unquote(value)
  end

  @spec input_schema(value_or_opts :: Xema.t() | keyword()) :: Macro.t()
  defmacro input_schema(value_or_opts) do
    {value, error_message} = case value_or_opts do
      [do: block] ->
        value = quote do
          import Xema.Builder
          unquote(block)
        end
        {value, "Block must return a valid Xema schema."}

      value ->
        {value, "Must be a valid Xema schema."}
    end

    quote do
      try do
        case unquote(value) do
          %Xema{} = schema -> @input_schema schema
          schema -> @input_schema Xema.new(schema)
        end
      rescue
        _ -> raise ArgumentError, unquote(error_message)
      end
    end
  end

  # Helpers

  @spec invoke_handler(handler :: handler() | {module(), function(), list()}, params :: any()) :: any()
  defp invoke_handler(handler, params) when is_function(handler, 1) do
    apply(handler, [params])
  end

  defp invoke_handler({mod, fun, args}, params) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [params | args])
  end

  @spec is_custom?(any()) :: boolean()
  defp is_custom?(%{type: :custom}), do: true
  defp is_custom?(data) when is_map(data), do: Map.get(data, :type) == nil
  defp is_custom?(_val), do: false

  @spec validate_input_schema(any()) :: :ok | {:error, String.t(), keyword()}
  defp validate_input_schema(%Xema{}), do: :ok
  defp validate_input_schema(%{type: _type}), do: :ok
  defp validate_input_schema(%{"type" => _type}), do: :ok
  defp validate_input_schema(_val), do: {:error, "Invalid schema. Define with Xema.new/2.", []}

  @spec validate_handler(any()) :: :ok | {:error, String.t(), keyword()}
  defp validate_handler(fun) when is_function(fun, 1), do: :ok
  defp validate_handler({mod, fun, args}) when is_atom(mod) and is_atom(fun) and is_list(args) do
    arity = length(args) + 1
    case function_exported?(mod, fun, arity) do
      true -> :ok
      false -> {:error, "Invalid handler. Module `#{inspect(mod)}` must export `#{inspect(fun)}/#{arity}`.", []}
    end
  end
  defp validate_handler(_val), do: {:error, "Invalid handler. Must be a function that takes 1 argument or MFA tuple.", []}

end
