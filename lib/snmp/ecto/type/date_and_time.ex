defmodule Snmp.Ecto.Type.DateAndTime do
  @moduledoc """
  Custom Ecto type for DateAndTime as in SNMPv2-TC
  """
  use Ecto.Type

  def type, do: :binary

  def cast(%DateTime{} = dt), do: {:ok, dt}

  def cast(%NaiveDateTime{} = dt), do: {:ok, dt}

  def cast(v) when is_binary(v) do
    {:ok, dt, 0} = DateTime.from_iso8601(v)
    {:ok, dt}
  rescue
    _ ->
      :error
  end

  def cast(_), do: :error

  def load(
        <<year::integer-size(16), month::integer, day::integer, hour::integer, minute::integer,
          second::integer, decisecond::integer, dir::binary-size(1), hour_shift::integer,
          min_shift::integer>>
      ) do
    tz = format_tz(dir, hour_shift, min_shift)

    "#{pad_int(year, 4)}-#{pad_int(month, 2)}-#{pad_int(day, 2)}T#{pad_int(hour, 2)}:#{
      pad_int(minute, 2)
    }:#{pad_int(second, 2)}.#{decisecond}#{tz}"
    |> DateTime.from_iso8601()
    |> case do
      {:ok, dt, _} -> {:ok, dt}
      {:error, _} -> :error
    end
  end

  def load(
        <<year::integer-size(16), month::integer, day::integer, hour::integer, minute::integer,
          second::integer, decisecond::integer>>
      ) do
    "#{pad_int(year, 4)}-#{pad_int(month, 2)}-#{pad_int(day, 2)}T#{pad_int(hour, 2)}:#{
      pad_int(minute, 2)
    }:#{pad_int(second, 2)}.#{decisecond}"
    |> NaiveDateTime.from_iso8601()
    |> case do
      {:ok, dt} -> {:ok, dt}
      {:error, _} -> :error
    end
  end

  def load(_), do: :error

  def dump(%DateTime{} = dt) do
    decisecond = dt.microsecond |> elem(0) |> div(100_000) |> round()

    {direction, hour_shift, min_shift} =
      case dt.utc_offset do
        shift when shift < 0 ->
          {<<?->>, div(shift, 60), rem(shift, 60)}

        shift ->
          {<<?+>>, div(shift, 60), rem(shift, 60)}
      end

    bin =
      <<dt.year::integer-size(16), dt.month::integer, dt.day::integer, dt.hour::integer,
        dt.minute::integer, dt.second::integer, decisecond::integer, direction::binary-size(1),
        hour_shift::integer, min_shift::integer>>

    {:ok, bin}
  end

  def dump(%NaiveDateTime{} = dt) do
    decisecond = dt.microsecond |> div(100_000) |> round()

    bin =
      <<dt.year::integer-size(16), dt.month::integer, dt.day::integer, dt.hour::integer,
        dt.minute::integer, dt.second::integer, decisecond::integer>>

    {:ok, bin}
  end

  def dump(_), do: :error

  defp format_tz(_, 0, 0), do: "Z"

  defp format_tz(dir, hour, min) do
    dir = <<dir::binary>>
    "#{dir}#{pad_int(hour, 2)}:#{pad_int(min, 2)}"
  end

  defp pad_int(i, width), do: "~#{width}..0b" |> :io_lib.format([i]) |> to_string()
end
