# SimpleISAM

A simple ISAM-like store backed by NDJSON files and ETS tables. Provides fast O(1) lookups through in-memory indexing while maintaining file persistence.

## Features

- Fast O(1) lookups through ETS tables
- Persistent storage using NDJSON files
- Support for multiple key fields
- Type-safe through structs
- Clean repository pattern for domain-specific operations
- Automatic cleanup of ETS tables

## Installation

Add `simple_isam` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:simple_isam, "~> 0.1.0"}
  ]
end
```

## Usage

SimpleISAM is designed to be used through repository facades. Here are two example implementations:

### Client Repository

```elixir
defmodule ClientRepository do
  use GenServer

  defmodule Client do
    @enforce_keys [:client_id]
    defstruct [:client_id, :name, :secret]
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    file_path = Keyword.fetch!(opts, :file_path)
    {:ok, pid} = SimpleISAM.start_link(
      file_path: file_path,
      key_fields: [:client_id]
    )
    {:ok, %{isam_pid: pid}}
  end

  # Client API
  def get_client(pid, client_id), do: GenServer.call(pid, {:get, client_id})
  def register_client(pid, client), do: GenServer.call(pid, {:register, client})
  def delete_client(pid, client_id), do: GenServer.call(pid, {:delete, client_id})
end
```

### Token Repository

```elixir
defmodule TokenRepository do
  use GenServer

  defmodule AccessToken do
    @enforce_keys [:access_token, :client_id]
    defstruct [:access_token, :client_id, :expires_at]
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    file_path = Keyword.fetch!(opts, :file_path)
    {:ok, pid} = SimpleISAM.start_link(
      file_path: file_path,
      key_fields: [:access_token]
    )
    {:ok, %{isam_pid: pid}}
  end

  # Client API
  def get_token(pid, token), do: GenServer.call(pid, {:get, token})
  def store_token(pid, token), do: GenServer.call(pid, {:store, token})
  def delete_token(pid, token), do: GenServer.call(pid, {:delete, token})
end
```

### Direct Usage (Not Recommended)

While it's possible to use SimpleISAM directly, we strongly recommend using it through repository facades:

```elixir
{:ok, pid} = SimpleISAM.start_link(
  file_path: "data.ndjson",
  key_fields: [:id, :email]
)

user = %{id: "user-1", email: "user@example.com", name: "Test User"}
{:ok, user} = SimpleISAM.insert(pid, user)

# Lookup by any key field
user = SimpleISAM.get(pid, :id, "user-1")
user = SimpleISAM.get(pid, :email, "user@example.com")

# Delete by any key field
{:ok, user} = SimpleISAM.delete(pid, :id, "user-1")
```

## Configuration

When starting SimpleISAM, you can configure:

- `file_path`: Path to the NDJSON file for persistence
- `key_fields`: List of fields to index for O(1) lookups

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

