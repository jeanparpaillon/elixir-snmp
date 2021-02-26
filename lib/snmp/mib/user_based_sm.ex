defmodule Snmp.Mib.UserBasedSm do
  @moduledoc """
  Functions for SNMP-USER-BASED-SM-MIB
  """
  require Snmp.Mib.Vacm

  alias Snmp.Mib.Vacm

  @type user_opt() ::
          {:user, String.Chars.t()} | {:password, String.Chars.t()} | {:access, atom() | [atom()]}

  @typedoc """
  A user definition in configuration

  # Options

  * `user`: user name
  * `password`: user password, used for both authentication and encryption,
    optional if referenced accesses are `noAuthNoPriv`
  * `access`: one or several accesses as defined in agent
  """
  @type user :: [user_opt()]

  @doc """
  Returns initial config for usm.conf
  """
  @spec config([user()], String.Chars.t(), map()) :: list()
  def config(users, engine_id, accesses) do
    users
    |> Enum.reduce([], fn attrs, acc ->
      sec_names = attrs |> Keyword.fetch!(:access) |> List.wrap()
      acc ++ Enum.map(sec_names, &new(engine_id, &1, attrs, accesses[&1]))
    end)
  end

  @doc """
  Returns a tuple representing a USM config
  """
  def new(_engine_id, sec_name, attrs, nil) do
    user = Keyword.fetch!(attrs, :user)
    raise "Access #{sec_name} for user #{user} does not exist"
  end

  def new(engine_id, sec_name, attrs, access) do
    user = Keyword.fetch!(attrs, :user)

    {auth_p, auth_key, priv_p, priv_key} =
      access
      |> Vacm.vacmAccess(:sec_level)
      |> case do
        :noPrivNoAuth ->
          {:usmNoAuthProtocol, '', :usmNoPrivProtocol, ''}

        :authNoPriv ->
          password = Keyword.fetch!(attrs, :password)
          auth_key = :snmp.passwd2localized_key(:md5, to_charlist(password), engine_id)
          {:usmHMACMD5AuthProtocol, auth_key, :usmNoPrivProtocol, ''}

        :authPriv ->
          password = Keyword.fetch!(attrs, :password)
          priv_key = auth_key = :snmp.passwd2localized_key(:md5, to_charlist(password), engine_id)
          {:usmHMACMD5AuthProtocol, auth_key, :usmAesCfb128Protocol, priv_key}
      end

    {
      engine_id,
      to_charlist(user),
      to_charlist(sec_name),
      :zeroDotZero,
      auth_p,
      '',
      '',
      priv_p,
      '',
      '',
      '',
      auth_key,
      priv_key
    }
  end
end
