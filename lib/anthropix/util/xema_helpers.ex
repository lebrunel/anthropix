defmodule Anthropix.Util.XemaHelpers do
  @moduledoc """
  Helper functions for working with Xema schemas.

  This module provides utilities to convert Xema schema structures into
  standard JSON Schema format. The conversion handles common schema elements
  and is particularly suitable for:

  - Simple object schema definitions
  - Structured data models used in LLM tools
  - Basic type validation schemas

  Note that while this implementation covers most common schema elements,
  it may not fully support all aspects of complex, deeply nested, or
  specialized schemas with advanced validation logic. For such cases,
  additional customization may be necessary.
  """

  @json_schema_keywords [
    {:comment, "$comment"},
    {:definitions, "$defs"},
    {:id, "$id"},
    {:ref, "$ref"},
    {:schema, "$schema"},
    :additional_properties,
    :all_of,
    :any_of,
    :const,
    :contains,
    :content_encoding,
    :content_media_type,
    :default,
    :description,
    :else,
    :enum,
    :examples,
    :exclusive_maximum,
    :exclusive_minimum,
    :format,
    :if,
    :items,
    :max_items,
    :max_length,
    :max_properties,
    :maximum,
    :min_items,
    :min_length,
    :min_properties,
    :minimum,
    :multiple_of,
    :not,
    :one_of,
    :pattern,
    :pattern_properties,
    :properties,
    :property_names,
    :required,
    :then,
    :title,
    :type,
    :unique_items
  ]

  @doc """
  Converts an Xema schema to a JSON schema map representation.

  This function transforms a Xema schema structure into a standard JSON Schema
  format that can be serialized to JSON. It handles the translation of
  Elixir-specific type names to their JSON Schema equivalents and properly
  formats schema properties according to the JSON Schema specification.
  """
  @spec xema_to_map(Xema.t() | Xema.schema()) :: map()
  def xema_to_map(%Xema{schema: schema}), do: xema_to_map(schema)

  def xema_to_map(%Xema.Schema{} = schema) do
    map = Enum.reduce(@json_schema_keywords, %{}, fn keyword, acc ->
      # Create key-value mappings
      {key, val} = case keyword do
        {src, dest} ->
          {dest, Map.get(schema, src)}

        :type ->
          val = Map.get(schema, :type) |> convert_type()
          {"type", val}

        key ->
          dest = Atom.to_string(key) |> Recase.to_camel()
          {dest, Map.get(schema, key)}
      end

      # Apply key value mappings, unless value is nil
      case val do
        nil -> acc
        val -> Map.put(acc, key, val)
      end
    end)

    deep_convert(map)
  end

  @spec deep_convert(any()) :: any()
  defp deep_convert(%Xema.Schema{} = val), do: xema_to_map(val)
  defp deep_convert(%Xema.Ref{}= val), do: Xema.Ref.key(val)
  defp deep_convert(%MapSet{} = val), do: MapSet.to_list(val) |> deep_convert()
  defp deep_convert(%Regex{} = val), do: Regex.source(val)
  defp deep_convert(val) when is_list(val), do: Enum.map(val, &deep_convert/1)
  defp deep_convert(val) when is_map(val), do: Map.new(val, &deep_convert/1)
  defp deep_convert({key, val}), do: {deep_convert(key), deep_convert(val)}
  defp deep_convert(val) when is_atom(val), do: Atom.to_string(val)
  defp deep_convert(val), do: val

  @spec convert_type(atom()) :: String.t()
  defp convert_type(:map), do: "object"
  defp convert_type(:list), do: "array"
  defp convert_type(nil), do: "null"
  defp convert_type(type), do: Atom.to_string(type)

end
