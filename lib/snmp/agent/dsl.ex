defmodule Snmp.Agent.DSL do
  @moduledoc """
  Defines macros for building SNMP Agent handler
  """
  alias Snmp.Agent.Error
  alias Snmp.Agent.Scope
  alias Snmp.Mib.Vacm

  @doc false
  defmacro __using__(_opts) do
    Module.register_attribute(__CALLER__.module, :mib, accumulate: true)
    Module.register_attribute(__CALLER__.module, :view, accumulate: true)
    Module.register_attribute(__CALLER__.module, :access, accumulate: true)
    Module.register_attribute(__CALLER__.module, :security_group, accumulate: true)

    quote do
      import unquote(__MODULE__), only: :macros

      @before_compile Snmp.Agent.Writer
    end
  end

  Module.register_attribute(__MODULE__, :placement, accumulate: true)

  @placement {:mib, [toplevel: true]}
  @doc """
  Declares a MIB
  """
  defmacro mib(module) do
    __CALLER__
    |> scope!(:mib, @placement[:mib])
    |> scope(:mib, module: Macro.expand(module, __CALLER__))

    quote do
      require unquote(module)
    end
  end

  @placement {:view, [toplevel: true]}
  @doc """
  Declares a view (see `SNMP-VIEW-BASED-ACM-MIB`)
  """
  defmacro view(name, do: block) do
    __CALLER__
    |> scope!(:view, @placement[:view])
    |> scope(:view, [name: Macro.expand(name, __CALLER__)], block)

    nil
  end

  @placement {:include, [under: [:view]]}
  @doc """
  Declares an included subtree in a view
  """
  defmacro include(oid) do
    __CALLER__
    |> scope!(:include, @placement[:include])
    |> scope(:include, oid: Macro.expand(oid, __CALLER__))

    nil
  end

  @placement {:exclude, [under: [:view]]}
  @doc """
  Declares an excluded subtree in a view
  """
  defmacro exclude(oid) do
    __CALLER__
    |> scope!(:exclude, @placement[:exclude])
    |> scope(:exclude, oid: Macro.expand(oid, __CALLER__))

    nil
  end

  @placement {:access, [toplevel: true]}
  @doc """
  Declares an access
  """
  defmacro access(name, opts) do
    opts =
      opts
      |> Enum.map(fn {key, ast} ->
        {key, Macro.expand(ast, __CALLER__)}
      end)
      |> Keyword.merge(name: name)

    __CALLER__
    |> scope!(:access, @placement[:access])
    |> scope(:access, opts)

    nil
  end

  def scope(env, kind, attrs, block \\ [])

  def scope(env, :include, [oid: oid], _block) do
    Scope.put_attribute(env.module, :include, oid, accumulate: true)
  end

  def scope(env, :exclude, [oid: oid], _block) do
    Scope.put_attribute(env.module, :exclude, oid, accumulate: true)
  end

  def scope(env, kind, attrs, block) do
    Scope.open(kind, env.module, attrs)

    block
    |> Macro.prewalk(&Macro.expand(&1, env))

    close_scope(env, kind, attrs)
  end

  defp close_scope(env, :mib, attrs) do
    Module.put_attribute(env.module, :mib, attrs)
    Scope.close(env.module)
  end

  defp close_scope(env, :view, _attrs) do
    %{attrs: attrs} = Scope.current(env.module)

    attrs
    |> Vacm.tree_families()
    |> Enum.each(&Module.put_attribute(env.module, :view, &1))

    Scope.close(env.module)
  end

  defp close_scope(env, :access, _attrs) do
    %{attrs: attrs} = Scope.current(env.module)

    {accesses, security_to_group} = Vacm.from_access(attrs)

    accesses
    |> Enum.each(&Module.put_attribute(env.module, :access, &1))

    security_to_group
    |> Enum.each(&Module.put_attribute(env.module, :security_group, &1))

    Scope.close(env.module)
  end

  defp close_scope(env, _kind, _attrs) do
    Scope.close(env.module)
  end

  def scope!(env, usage) do
    scope!(env, usage, Keyword.get(@placement, usage, []))
  end

  def scope!(env, usage, kw_rules, opts \\ []) do
    do_scope!(env, usage, Enum.into(List.wrap(kw_rules), %{}), opts)
  end

  defp do_scope!(env, usage, %{under: parents} = rules, opts) do
    case Scope.current(env.module) do
      %{name: name} ->
        if Enum.member?(List.wrap(parents), name) do
          do_scope!(env, usage, Map.delete(rules, :under), opts)
        else
          raise Error, only_within(usage, parents, opts)
        end

      _ ->
        raise Error, only_within(usage, parents, opts)
    end
  end

  defp do_scope!(env, usage, %{toplevel: true} = rules, opts) do
    case Scope.current(env.module) do
      nil ->
        do_scope!(env, usage, Map.delete(rules, :toplevel), opts)

      _ ->
        ref = opts[:as] || "`#{usage}`"

        raise Error,
              "Invalid agent definition: #{ref} must only be used toplevel"
    end
  end

  defp do_scope!(env, usage, %{toplevel: false} = rules, opts) do
    case Scope.current(env.module) do
      nil ->
        ref = opts[:as] || "`#{usage}`"

        raise Error,
              "Invalid agent definition: #{ref} must not be used toplevel"

      _ ->
        do_scope!(env, usage, Map.delete(rules, :toplevel), opts)
    end
  end

  defp do_scope!(env, _, rules, _) when map_size(rules) == 0 do
    env
  end

  # The error message when a macro can only be used within a certain set of
  # parent scopes.
  defp only_within(usage, parents, opts) do
    ref = opts[:as] || "`#{usage}`"

    parts =
      List.wrap(parents)
      |> Enum.map_join(", ", &"`#{&1}`")

    "Invalid agent definition: #{ref} must only be used within #{parts}"
  end
end
