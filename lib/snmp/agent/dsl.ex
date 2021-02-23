defmodule Snmp.Agent.DSL do
  @moduledoc """
  Defines macros for building SNMP Agent handler
  """
  alias Snmp.Agent.Error
  alias Snmp.Agent.Scope

  @doc false
  defmacro __using__(_opts) do
    Module.register_attribute(__CALLER__.module, :mib, accumulate: true)

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
    |> scope(:mib, module: module)

    quote do
      require unquote(module)
    end
  end

  # @doc """
  # Declares a view (see `SNMP-VIEW-BASED-ACM-MIB`)
  # """
  # defmacro view(name, do: block) do
  #   quote do
  #     @view
  #   end
  # end

  def scope(env, kind, attrs) do
    open_scope(env, kind, attrs)
    close_scope(env, kind, attrs)
  end

  defp open_scope(env, kind, attrs) do
    Scope.open(kind, env.module, attrs)
  end

  defp close_scope(env, :mib, attrs) do
    attrs =
      attrs
      |> Enum.map(fn {key, ast} ->
        {key, Macro.expand(ast, env)}
      end)
    Module.put_attribute(env.module, :mib, attrs)
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
      |> Enum.map(&"`#{&1}`")
      |> Enum.join(", ")

    "Invalid agent definition: #{ref} must only be used within #{parts}"
  end
end
