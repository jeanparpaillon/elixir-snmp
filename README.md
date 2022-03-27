# elixir-snmp

[![CircleCI](https://circleci.com/gh/jeanparpaillon/elixir-snmp.svg?style=shield)](https://app.circleci.com/pipelines/github/jeanparpaillon/elixir-snmp)
[![Hex version](https://img.shields.io/hexpm/v/elixir_snmp.svg "Hex version")](https://hex.pm/packages/elixir_snmp)
[![Documentation](https://img.shields.io/badge/hex-docs-green.svg)](https://hexdocs.pm/elixir_snmp/)
[![Total Download](https://img.shields.io/hexpm/dt/elixir_snmp.svg?maxAge=2592000)](https://hex.pm/packages/elixir_snmp)
[![License](https://img.shields.io/hexpm/l/elixir_snmp.svg?maxAge=259200)](https://github.com/jeanparpaillon/elixir_snmp/blob/master/LICENSE)

Have you tried to integrate SNMP in your application but afraid of [OTP
snmp](http://erlang.org/doc/man/SNMP_app.html) documentation ? `elixir-snmp` may
be the answer.

## Installation

The package can be installed by adding `elixir_snmp` to your list of dependencies in `mix.exs` :

``` elixir
def deps do
  [
    {:elixir_snmp, "~> 0.2.1"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/elixir_snmp](https://hexdocs.pm/elixir_snmp).

## Quickstart

`elixir_snmp` provides DSL and macros for easily:
* Instrumenting MIBs, *ie* creates functions that map MIB variables accesses to
  elixir code;
* Describing SNMP agent and its configuration.

### Configure or add directories, add .mib file(s)
* By default, `elixir_snmp` expects you to have to have non standard .mib files
in `mibs/*.mib` (they will be compiled into `priv/mibs/*.bin`. Standard MIBs are
provided with OTP in `<otp>/lib/snmp-<version>/mibs/` and do not need to be
included. MIB compilation is quite complex: `use Snmp.Mib` (see [Instrumenting MIB below](https://github.com/jeanparpaillon/elixir-snmp#instrumenting-mib))
is not enough to compile MIB files, and `.mib` files need to be already compiled
into `*.bin` when compiling elixir code. So `:mib` compiler can be added in the
list of compilers of the application (see https://github.com/jeanparpaillon/elixir-snmp/blob/master/lib/mix/tasks/compile.mib.ex).

See related config options
  [here](https://github.com/jeanparpaillon/elixir-snmp/blob/4c37a2d511917bf99029625844666b8ab0f5ac0c/lib/snmp/compiler/options.ex#L3-L4).

### Instrumenting MIB
* As noted below in [Defining Agent](https://github.com/jeanparpaillon/elixir-snmp#defining-agent), there are two mandatory SNMP mibs. You
will need to create Elixir Mib modules (not to be confused with .mib files) for
these, you don't have to define your own instrumentation functions. Remember to
update the (required) confs values below:

``` elixir
defmodule MyApp.Mib.Standard do
  use Snmp.Mib.Standard,
    otp_app: :my_app,
    conf: [
      sysObjectID: ,
      snmpEnableAuthenTraps: ,
      sysServices: []
    ]
end
```

``` elixir
defmodule MyApp.Mib.Framework do
  use Snmp.Mib.Framework,
   otp_app: :my_app,
   conf: [
     snmpEngineID: ,
     snmpEngineMaxMessageSize: ,
     sysObjectID: ,
     sysServices: ,
     snmpEnableAuthenTraps:
   ]
end
```
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
  use Snmp.Agent.Handler, otp_app: :my_app

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
    [user: "public", access: :public],
    [user: "admin", password: "adminpassword", access: [:public, :secure]]
  ]
```

See `Snmp.Agent` for advanced Agent DSL usage and configuration.

## TODO

See [Github issues](https://github.com/jeanparpaillon/elixir-snmp/issues)
