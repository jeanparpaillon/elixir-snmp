defmodule Snmp.Mib.Vacm do
  @moduledoc """
  Defines VACM entry types
  """
  import Record

  @default_tree_family [type: :included, mask: :null]
  defrecord :vacmViewTreeFamily, name: nil, sub_tree: [], type: :included, mask: :null

  defrecord :vacmSecurityToGroup, [:sec_model, :sec_name, :group_name]

  defrecord :vacmAccess, [
    :group_name,
    :prefix,
    :sec_model,
    :sec_level,
    :match,
    :read_view,
    :write_view,
    :notify_view
  ]

  @doc false
  def tree_family(attrs) do
    %{name: name, sub_tree: sub_tree, type: type, mask: mask} =
      @default_tree_family
      |> Keyword.merge(attrs)
      |> Enum.into(%{})

    vacmViewTreeFamily(name: name, sub_tree: sub_tree, type: type, mask: mask)
  end

  @doc false
  def tree_families(attrs) do
    name = Keyword.fetch!(attrs, :name)
    includes = Keyword.get(attrs, :include, [])
    excludes = Keyword.get(attrs, :exclude, [])

    Enum.map(includes, &tree_family(name: name, sub_tree: &1, type: :included)) ++
      Enum.map(excludes, &tree_family(name: name, sub_tree: &1, type: :excluded))
  end
end
