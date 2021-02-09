defmodule Snmp.Mib.Parser do
  @moduledoc false

  @reserved_words [
    # v1
    :ACCESS,
    :BEGIN,
    :BIT,
    :"CONTACT-INFO",
    :Counter,
    :DEFINITIONS,
    :DEFVAL,
    :DESCRIPTION,
    :"DISPLAY-HINT",
    :END,
    :ENTERPRISE,
    :FROM,
    :Gauge,
    :IDENTIFIER,
    :IDENTIFIER,
    :IMPORTS,
    :INDEX,
    :INTEGER,
    :IpAddress,
    :"LAST-UPDATED",
    :NetworkAddress,
    :OBJECT,
    :OBJECT,
    :"OBJECT-TYPE",
    :OCTET,
    :OF,
    :Opaque,
    :REFERENCE,
    :SEQUENCE,
    :SIZE,
    :STATUS,
    :STRING,
    :SYNTAX,
    :"TRAP-TYPE",
    :TimeTicks,
    :VARIABLES,

    # v2
    :"LAST-UPDATED",
    :ORGANIZATION,
    :"CONTACT-INFO",
    :"MODULE-IDENTITY",
    :"NOTIFICATION-TYPE",
    :"MODULE-COMPLIANCE",
    :"OBJECT-GROUP",
    :"NOTIFICATION-GROUP",
    :REVISION,
    :"OBJECT-IDENTITY",
    :"MAX-ACCESS",
    :UNITS,
    :AUGMENTS,
    :IMPLIED,
    :OBJECTS,
    :"TEXTUAL-CONVENTION",
    :"OBJECT-GROUP",
    :"NOTIFICATION-GROUP",
    :NOTIFICATIONS,
    :"MODULE-COMPLIANCE",
    :"AGENT-CAPABILITIES",
    :"PRODUCT-RELEASE",
    :SUPPORTS,
    :INCLUDES,
    :MODULE,
    :"MANDATORY-GROUPS",
    :GROUP,
    :"WRITE-SYNTAX",
    :"MIN-ACCESS",
    :BITS
  ]

  @doc false
  def from_file(path) do
    verbosity = Process.put(:verbosity, :silence)
    snmp_version = Process.put(:snmp_version, 2)

    ret =
      case :snmpc_tok.start_link(@reserved_words, file: '#{path}', forget_stringdata: true) do
        {:error, err} ->
          {:error, err}

        {:ok, pid} ->
          toks = :snmpc_tok.get_all_tokens(pid)
          :snmpc_tok.stop(pid)

          :snmpc_mib_gram.parse(toks)
      end

    # Restore process dictionary
    Process.put(:verbosity, verbosity)
    Process.put(:snmp_version, snmp_version)

    ret
  end
end
