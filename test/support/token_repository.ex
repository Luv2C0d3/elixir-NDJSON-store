defmodule TokenRepository do
  @moduledoc """
  A facade for SimpleISAM that provides token-specific operations.
  This repository handles both access tokens and refresh tokens in a single NDJSON file.
  """

  use GenServer
  require Logger

  defmodule AccessToken do
    @enforce_keys [:access_token, :client_id, :scope]
    defstruct [
      :access_token,
      :client_id,
      :scope,
      :expires_at
    ]
  end

  defmodule RefreshToken do
    @enforce_keys [:refresh_token, :client_id, :scope]
    defstruct [
      :refresh_token,
      :client_id,
      :scope
    ]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Stores an access token.
  Returns {:ok, token} on success.
  """
  def insert_access_token(pid, %AccessToken{} = token) do
    GenServer.call(pid, {:insert_access_token, token})
  end

  @doc """
  Stores a refresh token.
  Returns {:ok, token} on success.
  """
  def insert_refresh_token(pid, %RefreshToken{} = token) do
    GenServer.call(pid, {:insert_refresh_token, token})
  end

  @doc """
  Retrieves an access token by its value.
  Returns nil if not found.
  """
  def get_access_token(pid, access_token) do
    GenServer.call(pid, {:get_access_token, access_token})
  end

  @doc """
  Retrieves a refresh token by its value.
  Returns nil if not found.
  """
  def get_refresh_token(pid, refresh_token) do
    GenServer.call(pid, {:get_refresh_token, refresh_token})
  end

  @doc """
  Deletes an access token by its value.
  Returns {:ok, token} on success, {:error, :not_found} if token doesn't exist.
  """
  def delete_access_token(pid, access_token) do
    GenServer.call(pid, {:delete_access_token, access_token})
  end

  @doc """
  Deletes a refresh token by its value.
  Returns {:ok, token} on success, {:error, :not_found} if token doesn't exist.
  """
  def delete_refresh_token(pid, refresh_token) do
    GenServer.call(pid, {:delete_refresh_token, refresh_token})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    file_path = Keyword.fetch!(opts, :file_path)
    buffer_size = Keyword.get(opts, :buffer_size, 100)
    {:ok, pid} = SimpleISAM.start_link(
      file_path: file_path,
      key_fields: [:access_token, :refresh_token],
      buffer_size: buffer_size
    )
    {:ok, %{isam_pid: pid}}
  end

  @impl true
  def handle_call({:insert_access_token, token}, _from, state) do
    case SimpleISAM.insert(state.isam_pid, token) do
      {:ok, _} -> {:reply, {:ok, token}, state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:insert_refresh_token, token}, _from, state) do
    case SimpleISAM.insert(state.isam_pid, token) do
      {:ok, _} -> {:reply, {:ok, token}, state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_access_token, access_token}, _from, state) do
    raw = SimpleISAM.get(state.isam_pid, :access_token, access_token)
    result =
      case raw do
        nil -> nil
        %AccessToken{} = s -> s
        other when is_map(other) -> struct(AccessToken, atomize_keys(other))
      end
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_refresh_token, refresh_token}, _from, state) do
    raw = SimpleISAM.get(state.isam_pid, :refresh_token, refresh_token)
    result =
      case raw do
        nil -> nil
        %RefreshToken{} = s -> s
        other when is_map(other) -> struct(RefreshToken, atomize_keys(other))
      end
    {:reply, result, state}
  end

  @impl true
  def handle_call({:delete_access_token, access_token}, _from, state) do
    result = SimpleISAM.delete(state.isam_pid, :access_token, access_token)
    case result do
      {:ok, map} ->
        token = struct(AccessToken, atomize_keys(map))
        {:reply, {:ok, token}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:delete_refresh_token, refresh_token}, _from, state) do
    result = SimpleISAM.delete(state.isam_pid, :refresh_token, refresh_token)
    case result do
      {:ok, map} ->
        token = struct(RefreshToken, atomize_keys(map))
        {:reply, {:ok, token}, state}

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
