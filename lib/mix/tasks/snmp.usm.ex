defmodule Mix.Tasks.Snmp.Usm do
  @moduledoc """
  Task for generating user credentials
  """
  use Mix.Task

  alias Snmp.Mib.UserBasedSm

  @shortdoc "SNMP User management tasks"

  @impl Mix.Task
  def run([]), do: usage(1)

  def run(["help" | _]), do: usage(0)

  def run(["gen_key", password]) do
    key = UserBasedSm.derive_aes_key(password)

    IO.puts """
    ##############################################################
    # WARNING!!!                                                 #
    #                                                            #
    # Keep this key in a secret place                            #
    ##############################################################
    base16: #{Base.encode16(key, case: :lower)}
    binary: #{inspect key}
    """

    :ok
  end

  def run(_), do: usage(1)

  @doc false
  def usage(code) do
    IO.puts """
    Usage: mix snmp.usm CMD CMD_ARGS

    Commands:
    * gen_key <password>      Generated AES encryption key from password
    """

    System.stop(code)
  end
end
