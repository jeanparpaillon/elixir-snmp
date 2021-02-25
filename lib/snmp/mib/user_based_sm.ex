defmodule Snmp.Mib.UserBasedSm do
  @moduledoc """
  Functions for SNMP-USER-BASED-SM-MIB
  """
  @default_aes_opts [salt: "ytlas", rounds: 10]

  @doc """
  Returns initial config for usm.conf
  """
  def config(users, engine_id, accesses) do
    users
    |> Enum.reduce([], fn attrs, acc ->
      sec_names = attrs |> Keyword.fetch!(:access) |> List.wrap()
      acc ++ Enum.map(sec_names, &new(engine_id, &1, attrs, accesses[&1]))
    end)
  end

  @doc """
  Derive AES key from password
  """
  @spec derive_aes_key(binary()) :: binary()
  def derive_aes_key(input) when is_binary(input) do
    aes_opts =
      @default_aes_opts
      |> Keyword.merge(Application.get_env(:snmpex, :aes_opts, []))

    Kryptonite.AES.derive_key(input, aes_opts)
  end

  @doc """
  Returns a tuple representing a USM config
  """
  def new(_engine_id, sec_name, attrs, nil) do
    user = Keyword.fetch!(attrs, :user)
    raise "Access #{sec_name} for user #{user} does not exist"
  end

  def new(engine_id, sec_name, attrs, _access) do
    user = Keyword.fetch!(attrs, :user)
    password = Keyword.fetch!(attrs, :password)

    {
      engine_id,
      user,
      sec_name,
      :zeroDotZero,
      :usmHMACMD5AuthProtocol,
      '',
      '',
      :usmAesCfb128Protocol,
      '',
      '',
      '',
      :md5 |> :crypto.hash(password) |> to_list(),
      password |> derive_aes_key() |> to_list()
    }
  end

  ###
  ### Priv
  ###
  defp to_list(bin) when is_binary(bin), do: binary_to_list(bin, [])

  defp binary_to_list(<<>>, acc), do: Enum.reverse(acc)

  defp binary_to_list(<<b, rest::binary>>, acc) do
    binary_to_list(rest, [b | acc])
  end
end
