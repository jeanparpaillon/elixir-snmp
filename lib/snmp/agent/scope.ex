defmodule Snmp.Agent.Scope do
  @moduledoc false

  @stack :snmp_agent_scope

  defstruct name: nil, attrs: []

  def open(name, mod, attrs \\ []) do
    Module.put_attribute(mod, @stack, [%__MODULE__{name: name, attrs: attrs} | on(mod)])
  end

  def close(mod) do
    {current, rest} = split(mod)
    Module.put_attribute(mod, @stack, rest)
    current
  end

  def split(mod) do
    case on(mod) do
      [] ->
        {nil, []}

      [current | rest] ->
        {current, rest}
    end
  end

  def current(mod) do
    {c, _} = split(mod)
    c
  end

  def put_attribute(mod, key, value, opts \\ [accumulate: false]) do
    if opts[:accumulate] do
      update_current(mod, fn scope ->
        new_attrs = update_in(scope.attrs, [key], &[value | &1 || []])
        %{scope | attrs: new_attrs}
      end)
    else
      update_current(mod, fn scope ->
        %{scope | attrs: Keyword.put(scope.attrs, key, value)}
      end)
    end
  end

  defp update_current(mod, fun) do
    {current, rest} = split(mod)
    updated = fun.(current)
    Module.put_attribute(mod, @stack, [updated | rest])
  end

  def on(mod) do
    case Module.get_attribute(mod, @stack) do
      nil ->
        Module.put_attribute(mod, @stack, [])
        []

      value ->
        value
    end
  end
end
