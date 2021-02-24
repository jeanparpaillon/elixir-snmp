defmodule Snmp.Mib.Vacm do
  @moduledoc """
  Defines VACM entry types
  """
  import Record

  alias Snmp.Agent.Error

  @default_tree_family [type: :included, mask: :null]
  defrecord :vacmViewTreeFamily, name: nil, sub_tree: [], type: :included, mask: :null

  defrecord :vacmSecurityToGroup, [:sec_model, :sec_name, :group_name]

  @default_sec_models [:v1, :v2c, :usm]
  @default_access [prefix: '', match: :exact, read_view: '', write_view: '', notify_view: '']
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
  def community(attrs) do
    name = Keyword.fetch!(attrs, :name)
    index = Keyword.get(attrs, :index, name)
    sec_name = Keyword.fetch!(attrs, :sec_name)
    ctx_name = Keyword.get(attrs, :context_name, '')
    transport_tag = Keyword.get(attrs, :transport_tag, '')
    {index, name, sec_name, ctx_name, transport_tag}
  end

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

  @doc false
  def access(attrs) do
    %{
      group_name: name,
      prefix: prefix,
      sec_model: sec_model,
      sec_level: sec_level,
      match: match,
      read_view: read_view,
      write_view: write_view,
      notify_view: notify_view
    } =
      @default_access
      |> Keyword.merge(attrs)
      |> Enum.into(%{})

    vacmAccess(
      group_name: to_charlist(name),
      prefix: prefix,
      sec_model: sec_model,
      sec_level: sec_level,
      match: match,
      read_view: to_charlist(read_view),
      write_view: to_charlist(write_view),
      notify_view: to_charlist(notify_view)
    )
  end

  @doc false
  def from_access(attrs) do
    group_name = sec_name = Keyword.fetch!(attrs, :name)
    sec_models = Keyword.get(attrs, :versions, @default_sec_models)
    level = Keyword.get(attrs, :level, :authPriv)
    community? = :v1 in sec_models or :v2c in sec_models

    if community? and level == :authPriv do
      raise Error, "Community based access is incompatible with security level `authPriv`"
    end

    accesses =
      sec_models
      |> Enum.map(
        &access(
          group_name: group_name,
          sec_model: &1,
          sec_level: level,
          match: :exact,
          read_view: Keyword.get(attrs, :read_view, ''),
          write_view: Keyword.get(attrs, :write_view, ''),
          notify_view: Keyword.get(attrs, :notify_view, '')
        )
      )

    security_to_group =
      sec_models
      |> Enum.map(&vacmSecurityToGroup(sec_model: &1, sec_name: sec_name, group_name: group_name))

    {accesses, security_to_group}
  end
end
