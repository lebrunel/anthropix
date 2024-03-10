defmodule Anthropix.Tool do
  use Anthropix.Schemas

  defdelegate el(name, attrs, content), to: Saxy.XML, as: :element

  defstruct name: nil,
            description: nil,
            params: [],
            function: nil

  @type t() :: %__MODULE__{
    name: String.t(),
    description: String.t(),
    params: list(param()),
    function: nil
  }

  @type param() :: %{
    name: String.t(),
    description: String.t(),
    type: String.t(),
  }

  schema :param, [
    name: [
      type: :string,
      required: true,
      doc: "todo"
    ],
    description: [
      type: :string,
      required: true,
      doc: "todo"
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
  TODO
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    opts
    |> NimbleOptions.validate!(schema(:tool))
    |> validate_function!()

    struct(__MODULE__, opts)
  end

#  @doc """
#  TODO
#  """
#  def to_xml(%__MODULE__{} = tool) do
#    xml = el(:tool_description, [], [
#      el(:tool_name, [], tool.name),
#      el(:description, [], tool.description),
#      el(:parameters, [], Enum.map(tool.params, &param_xml/1))
#    ])
#    Anthropix.XML.to_string(xml)
#  end
#
#  @spec param_xml(param()) :: tuple()
#  defp param_xml(%{name: name, type: type, description: description}) do
#    el(:param, [], [
#      el(:name, [], name),
#      el(:type, [], type),
#      el(:description, [], description),
#    ])
#  end

  # TODO
  @spec validate_function!(keyword()) :: :ok
  defp validate_function!(opts) do
    params = Keyword.get(opts, :params)

    case Keyword.get(opts, :function) do
      fun when is_function(fun) ->
        unless is_function(fun, length(params)) do
          raise %NimbleOptions.ValidationError{
            key: :function,
            value: fun,
            message: "Incorrect function arity for parameters"
          }
        end

      {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
        unless function_exported?(mod, fun, length(params) + length(args)) do
          raise %NimbleOptions.ValidationError{
            key: :function,
            value: fun,
            message: "Incorrect function arity for parameters"
          }
        end

      val ->
        raise %NimbleOptions.ValidationError{
          key: :function,
          value: val,
          message: "Must be anonymous function or {mod, function, args}"
        }
    end
    :ok
  end


end
