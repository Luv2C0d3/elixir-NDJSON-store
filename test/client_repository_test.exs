defmodule ClientRepositoryTest do
  use ExUnit.Case
  alias ClientRepository.OAuthClient
  require Logger

  setup do
    # Create a temporary directory for test files
    tmp_dir = Path.join([System.tmp_dir!(), "client_repo_test", to_string(:rand.uniform(1000000))])
    File.mkdir_p!(tmp_dir)
    client_file = Path.join(tmp_dir, "clients.ndjson")

    # Start ClientRepository with the test file
    {:ok, pid} = ClientRepository.start_link(file_path: client_file)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    %{pid: pid, client_file: client_file}
  end

  test "registers and retrieves oauth clients", %{pid: pid} do
    client = %OAuthClient{
      client_id: "oauth-client-1",
      client_secret: "oauth-client-secret-1",
      name: "Test OAuth Client",
      redirect_uris: ["http://localhost:9000/callback"],
      scopes: ["foo", "bar", "bazuka"]
    }

    # Register client
    assert {:ok, ^client} = ClientRepository.register_client(pid, client)

    # Retrieve client
    assert ^client = ClientRepository.get_client(pid, "oauth-client-1")

    # Non-existent client returns nil
    assert nil == ClientRepository.get_client(pid, "nonexistent")
  end

  test "updates existing clients", %{pid: pid} do
    client = %OAuthClient{
      client_id: "oauth-client-1",
      client_secret: "oauth-client-secret-1",
      name: "Test OAuth Client",
      redirect_uris: ["http://localhost:9000/callback"],
      scopes: ["foo", "bar", "bazuka"]
    }

    # Register client
    assert {:ok, ^client} = ClientRepository.register_client(pid, client)

    updated_client = %OAuthClient{
      client_id: "oauth-client-1",
      client_secret: "oauth-client-secret-1-updated",
      name: "Updated Test OAuth Client",
      redirect_uris: ["http://localhost:9000/callback", "http://example.com/callback"],
      scopes: ["foo", "bar", "bazuka", "extra"]
    }

    # Update client
    assert {:ok, ^updated_client} = ClientRepository.update_client(pid, updated_client)
    assert ^updated_client = ClientRepository.get_client(pid, "oauth-client-1")
  end

  test "handles update of non-existent client", %{pid: pid} do
    client = %OAuthClient{
      client_id: "nonexistent",
      client_secret: "secret",
      name: "Test Client"
    }

    assert {:error, :not_found} = ClientRepository.update_client(pid, client)
  end

  test "deletes clients", %{pid: pid} do
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

    # Register clients
    assert {:ok, ^client1} = ClientRepository.register_client(pid, client1)
    assert {:ok, ^client2} = ClientRepository.register_client(pid, client2)

    # Delete first client
    assert {:ok, ^client1} = ClientRepository.delete_client(pid, "oauth-client-1")
    assert nil == ClientRepository.get_client(pid, "oauth-client-1")
    # Second client should still exist
    assert ^client2 = ClientRepository.get_client(pid, "oauth-client-2")

    # Attempt to delete non-existent client
    assert {:error, :not_found} = ClientRepository.delete_client(pid, "nonexistent")
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

    # Register clients
    assert {:ok, ^client1} = ClientRepository.register_client(pid, client1)
    assert {:ok, ^client2} = ClientRepository.register_client(pid, client2)

    # Verify retrieval
    assert ^client1 = ClientRepository.get_client(pid, "oauth-client-1")
    assert ^client2 = ClientRepository.get_client(pid, "oauth-client-2")
  end
end
