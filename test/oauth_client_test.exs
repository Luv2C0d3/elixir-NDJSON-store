defmodule SimpleISAM.OAuthClientTest do
  use ExUnit.Case
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

  setup do
    # Create a temporary directory for test files
    tmp_dir = Path.join([System.tmp_dir!(), "simple_isam_test", to_string(:rand.uniform(1000000))])
    File.mkdir_p!(tmp_dir)
    test_file = Path.join(tmp_dir, "oauth_clients.ndjson")

    # Start SimpleISAM with the test file
    {:ok, pid} = SimpleISAM.start_link(
      file_path: test_file,
      key_fields: [:client_id],
      struct_type: OAuthClient
    )

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    %{pid: pid, test_file: test_file}
  end

  test "stores and retrieves oauth clients", %{pid: pid} do
    client = %OAuthClient{
      client_id: "oauth-client-1",
      client_secret: "oauth-client-secret-1",
      name: "Test OAuth Client",
      redirect_uris: ["http://localhost:9000/callback"],
      scopes: ["foo", "bar", "bazuka"]
    }

    assert {:ok, ^client} = SimpleISAM.insert(pid, client)
    assert ^client = SimpleISAM.get(pid, :client_id, "oauth-client-1")
  end

  test "returns nil for non-existent clients", %{pid: pid} do
    assert nil == SimpleISAM.get(pid, :client_id, "nonexistent")
  end

  test "updates existing clients", %{pid: pid} do
    client = %OAuthClient{
      client_id: "oauth-client-1",
      client_secret: "oauth-client-secret-1",
      name: "Test OAuth Client",
      redirect_uris: ["http://localhost:9000/callback"],
      scopes: ["foo", "bar", "bazuka"]
    }

    assert {:ok, ^client} = SimpleISAM.insert(pid, client)

    updated_client = %OAuthClient{
      client_id: "oauth-client-1",
      client_secret: "oauth-client-secret-1-updated",
      name: "Updated Test OAuth Client",
      redirect_uris: ["http://localhost:9000/callback", "http://example.com/callback"],
      scopes: ["foo", "bar", "bazuka", "extra"]
    }

    assert {:ok, ^updated_client} = SimpleISAM.insert(pid, updated_client)
    assert ^updated_client = SimpleISAM.get(pid, :client_id, "oauth-client-1")
  end

  test "deletes clients", %{pid: pid} do
    client = %OAuthClient{
      client_id: "oauth-client-1",
      client_secret: "oauth-client-secret-1",
      name: "Test OAuth Client",
      redirect_uris: ["http://localhost:9000/callback"],
      scopes: ["foo", "bar", "bazuka"]
    }

    assert {:ok, ^client} = SimpleISAM.insert(pid, client)
    assert {:ok, ^client} = SimpleISAM.delete(pid, :client_id, "oauth-client-1")
    assert nil == SimpleISAM.get(pid, :client_id, "oauth-client-1")
  end

  test "handles non-existent client deletion", %{pid: pid} do
    assert {:error, :not_found} = SimpleISAM.delete(pid, :client_id, "nonexistent")
  end

  test "handles multiple clients", %{pid: pid} do
    client1 = %OAuthClient{
      client_id: "oauth-client-1",
      client_secret: "oauth-client-secret-1",
      name: "Test OAuth Client",
      redirect_uris: ["http://localhost:9000/callback"],
      scopes: ["foo", "bar", "bazuka"]
    }

    client2 = %OAuthClient{
      client_id: "oauth-client-2",
      client_secret: "oauth-client-secret-2",
      name: "Another Test Client",
      redirect_uris: ["http://localhost:8080/callback", "http://example.com/oauth/callback"],
      scopes: ["read", "write"]
    }

    assert {:ok, ^client1} = SimpleISAM.insert(pid, client1)
    assert {:ok, ^client2} = SimpleISAM.insert(pid, client2)

    assert ^client1 = SimpleISAM.get(pid, :client_id, "oauth-client-1")
    assert ^client2 = SimpleISAM.get(pid, :client_id, "oauth-client-2")
  end
end
