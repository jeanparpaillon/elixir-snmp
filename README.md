# elixir-snmp

[![CircleCI](https://circleci.com/gh/jeanparpaillon/elixir-snmp.svg?style=shield)](https://app.circleci.com/pipelines/github/jeanparpaillon/elixir-snmp)

Have you tried to integrate SNMP in your application but afraid of [OTP
snmp](http://erlang.org/doc/man/SNMP_app.html) documentation ? `elixir-snmp` may
be the answer.

## Installation

The package can be installed by adding `elixir_snmp` to your list of dependencies in `mix.exs` :

``` elixir
def deps do
  [
    {:elixir_snmp, "~> 0.1.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/elixir_snmp](https://hexdocs.pm/elixir_snmp).

## Quickstart

`elixir_snmp` provides DSL and macros for easily:
* Instrumenting MIBs, *ie* creates functions that map MIB variables accesses to
  elixir code;
* Describing SNMP agent and its configuration.

### Instrumenting MIB

* Instrument a MIB with generic (mnesia) functions:

``` elixir
defmodule MyMib do
  use Snmp.Mib,
    name: "MY-MIB",
    instrumentation: Snmp.Instrumentation.Generic
end
```

* Instrument a MIB with your own functions (see [Definition of Instrumentation
  Functions](http://erlang.org/doc/apps/snmp/snmp_def_instr_functions.html) for signature):

``` elixir
defmodule MyMib do
  use Snmp.Mib,
    name: "MY-MIB"

  def my_variable(:get), do: {:value, "value"}

  def my_rw_variable(:get), do: {:value, "value"}

  def my_rw_variable(:set, val), do: :noError
end
```

See `Snmp.Mib` documentation for advanced instructions.

### Defining Agent

``` elixir
defmodule Agent do
  use Snmp.Agent

  # Mandatory MIBs
  mib MyApp.Mib.Standard
  mib MyApp.Mib.Framework

  # Application MIBs
  mib MyMib

  # VACM model
  view :public do
    include [1, 3, 6, 1, 2, 1]
  end

  view :private do
    include [1, 3, 6]
  end

  access :public,
    versions: [:v1, :v2c, :usm],
    level: :noAuthNoPriv,
    read_view: :public

  access :secure,
    versions: [:usm],
    level: :authPriv,
    read_view: :private,
    write_view: :private,
    notify_view: :private
end
```

Then, in your application env, defines some users:

``` elixir
config :my_app, Agent,
  versions: [:v1, :v2, :v3],
  port: "SNMP_PORT" |> System.get_env("4000") |> String.to_integer(),
  transports: ["127.0.0.1"],
  security: [
    [user: "public", access: :public]
    [user: "admin", password: "adminpassword", access: [:public, :secure]]
  ]
```

See `Snmp.Agent` for advanced Agent DSL usage and configuration.

## TODO

See [Github issues](https://github.com/jeanparpaillon/elixir-snmp/issues)
