defmodule ClientRepository do
  @moduledoc """
  A facade for SimpleISAM that provides client operations.
  This repository handles client registration and lookup.
  """

  use GenServer
  require Logger

  defmodule OAuthClient do
    @moduledoc """
    Represents an OAuth client with its configuration.
    """

    @enforce_keys [:client_id]
    defstruct [
      :client_id,
      :client_secret,
      :name,
      redirect_uris: [],
      scopes: []
    ]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Registers a new OAuth client.
  Returns {:ok, client} on success.
  """
  def register_client(pid, %OAuthClient{} = client) do
    GenServer.call(pid, {:register_client, client})
  end

  @doc """
  Retrieves a client by its client_id.
  Returns nil if not found.
  """
  def get_client(pid, client_id) do
    GenServer.call(pid, {:get_client, client_id})
  end

  @doc """
  Updates an existing client.
  Returns {:ok, client} on success.
  """
  def update_client(pid, %OAuthClient{} = client) do
    GenServer.call(pid, {:update_client, client})
  end

  @doc """
  Deletes a client by its client_id.
  Returns {:ok, client} on success, {:error, :not_found} if client doesn't exist.
  """
  def delete_client(pid, client_id) do
    GenServer.call(pid, {:delete_client, client_id})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    file_path = Keyword.fetch!(opts, :file_path)
    {:ok, pid} = SimpleISAM.start_link(
      file_path: file_path,
      key_fields: [:client_id]
    )
    {:ok, %{isam_pid: pid}}
  end

  @impl true
  def handle_call({:register_client, client}, _from, state) do
    case SimpleISAM.insert(state.isam_pid, client) do
      {:ok, _} -> {:reply, {:ok, client}, state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_client, client_id}, _from, state) do
    raw = SimpleISAM.get(state.isam_pid, :client_id, client_id)
    result =
      case raw do
        nil -> nil
        %OAuthClient{} = s -> s
        other when is_map(other) -> struct(OAuthClient, atomize_keys(other))
      end
    {:reply, result, state}
  end

  @impl true
  def handle_call({:update_client, client}, _from, state) do
    case SimpleISAM.get(state.isam_pid, :client_id, client.client_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _existing ->
        case SimpleISAM.insert(state.isam_pid, client) do
          {:ok, _} -> {:reply, {:ok, client}, state}
          error -> {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:delete_client, client_id}, _from, state) do
    result = SimpleISAM.delete(state.isam_pid, :client_id, client_id)
    case result do
      {:ok, map} ->
        client = struct(OAuthClient, atomize_keys(map))
        {:reply, {:ok, client}, state}

      error ->
        {:reply, error, state}
    end
  end

  # Private helpers

  defp atomize_keys(%_{} = struct), do: struct |> Map.from_struct() |> atomize_keys()
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_atom(k), v} end)
  end

  defp to_atom(key) when is_atom(key), do: key
  defp to_atom(key) when is_binary(key), do: String.to_atom(key)
end
