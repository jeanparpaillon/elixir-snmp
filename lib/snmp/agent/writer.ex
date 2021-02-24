defmodule Snmp.Agent.Writer do
  @moduledoc false

  defmacro __before_compile__(env) do
    mibs =
      env
      |> check_mibs!()
      |> build_mibs()

    views = Module.get_attribute(env.module, :view, [])
    accesses = Module.get_attribute(env.module, :access, [])
    security_groups = Module.get_attribute(env.module, :security_group, [])

    quote do
      def __agent__(:mibs), do: unquote(Macro.escape(mibs))
      def __agent__(:views), do: unquote(Macro.escape(views))
      def __agent__(:accesses), do: unquote(Macro.escape(accesses))
      def __agent__(:security_groups), do: unquote(Macro.escape(security_groups))
      def __agent__(:app), do: @otp_app
    end
  end

  defp check_mibs!(env) do
    mib_mods =
      env.module
      |> Module.get_attribute(:mib, [])
      |> Enum.map(&Keyword.fetch!(&1, :module))

    mib_mods
    |> Enum.reject(&Kernel.function_exported?(&1, :__mib__, 1))
    |> case do
      [] ->
        :ok

      invalid ->
        Mix.raise("The following modules do not implement a MIB: " <> Enum.join(invalid, " "))
    end

    mib_mods
  end

  defp build_mibs(mib_mods) do
    mib_mods
    |> Enum.map(&{apply(&1, :__mib__, [:name]), &1})
    |> Enum.into(%{})
  end
end
