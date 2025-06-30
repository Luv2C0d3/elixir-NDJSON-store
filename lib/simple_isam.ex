defmodule SimpleISAM do
  @moduledoc """
  Very small ISAM-like store backed by an NDJSON file and an ETS cache.

  • Accepts a list of key fields at start (atoms or strings)
  • Stores any Elixir map/struct (structs are converted to maps before persistence)
  • Provides insert/get/delete by key
  • Each SimpleISAM process owns its own ETS table; tables die with the process so
    we don't bother with explicit cleanup.
  """

  use GenServer
  require Logger

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec insert(pid(), struct() | map()) :: {:ok, any()} | {:error, term()}
  def insert(pid, record), do: GenServer.call(pid, {:insert, record})

  @spec get(pid(), atom() | String.t(), any()) :: map() | nil
  def get(pid, key_field, key_val), do: GenServer.call(pid, {:get, key_field, key_val})

  @spec delete(pid(), atom() | String.t(), any()) :: :ok | {:error, :not_found}
  def delete(pid, key_field, key_val),
    do: GenServer.call(pid, {:delete, key_field, key_val})

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    file_path  = Keyword.fetch!(opts, :file_path)
    key_fields = Keyword.fetch!(opts, :key_fields)

    # Ensure dir exists
    file_path |> Path.dirname() |> File.mkdir_p!()

    # Create an anonymous ETS table owned by this process
    table = :ets.new(:simple_isam_cache, [:set, :protected])

    # Load persisted records (if file exists)
    persisted = load_from_file(file_path)

    Enum.each(persisted, fn rec ->
      cache_record(table, key_fields, rec, rec)
    end)

    {:ok, %{file_path: file_path, key_fields: key_fields, table: table}}
  end

  @impl true
  def handle_call({:insert, raw_record}, _from, state) do
    sanitized = sanitize_record(raw_record)

    cache_record(state.table, state.key_fields, sanitized, raw_record)
    append_to_file(state.file_path, sanitized)

    {:reply, {:ok, raw_record}, state}
  end

  @impl true
  def handle_call({:get, key_field, key_val}, _from, state) do
    key = make_key(key_field, key_val)
    case :ets.lookup(state.table, key) do
      [{^key, rec}] -> {:reply, rec, state}
      []            -> {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:delete, key_field, key_val}, _from, state) do
    key = make_key(key_field, key_val)

    case :ets.lookup(state.table, key) do
      [] -> {:reply, {:error, :not_found}, state}
      [{^key, record}] ->
        # Remove all keys that point at this record
        Enum.each(state.key_fields, fn kf ->
          val = Map.get(record, kf)
          if val != nil, do: :ets.delete(state.table, make_key(kf, val))
        end)

        rewrite_file(state.file_path, state.table)
        {:reply, :ok, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp sanitize_record(%_{} = struct), do: Map.from_struct(struct) |> sanitize_record()
  defp sanitize_record(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_atom(k), v} end)
  end

  defp to_atom(k) when is_atom(k), do: k
  defp to_atom(k) when is_binary(k), do: String.to_atom(k)

  defp cache_record(table, key_fields, sanitized_map, stored_record) do
    Enum.each(key_fields, fn kf ->
      val = Map.get(sanitized_map, kf)
      if val != nil do
        :ets.insert(table, {make_key(kf, val), stored_record})
      end
    end)
  end

  defp append_to_file(path, record) do
    json = Jason.encode!(record)
    File.write!(path, json <> "\n", [:append])
  end

  defp load_from_file(path) do
    if File.exists?(path) do
      path
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.reject(&(&1 == ""))
      |> Enum.map(fn line -> line |> Jason.decode!() |> sanitize_record() end)
    else
      []
    end
  end

  defp rewrite_file(path, table) do
    records =
      :ets.tab2list(table)
      |> Enum.map(fn {_, rec} -> rec end)
      |> Enum.uniq()

    File.write!(path, "")
    Enum.each(records, fn rec -> append_to_file(path, sanitize_record(rec)) end)
  end

  defp make_key(kf, val), do: {kf, val}
end
