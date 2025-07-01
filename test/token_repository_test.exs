defmodule TokenRepositoryTest do
  use ExUnit.Case
  alias TokenRepository.{AccessToken, RefreshToken}
  require Logger

  setup do
    # Create a temporary directory for test files
    tmp_dir = Path.join([System.tmp_dir!(), "token_repo_test", to_string(:rand.uniform(1000000))])
    File.mkdir_p!(tmp_dir)
    token_file = Path.join(tmp_dir, "tokens.ndjson")

    # Start TokenRepository with the test file
    {:ok, pid} = TokenRepository.start_link(file_path: token_file)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    %{pid: pid, token_file: token_file}
  end

  test "stores and retrieves access tokens", %{pid: pid} do
    token = %AccessToken{
      access_token: "rsgaobZaE09V4OA8kQDkP9d3pn-KCw5aTTR8pcf_Mw8",
      client_id: "oauth-client-1",
      scope: ["foo", "bar", "bazuka"],
      expires_at: "2025-06-29T21:41:47.088Z"
    }

    # Store token
    assert {:ok, ^token} = TokenRepository.insert_access_token(pid, token)

    # Retrieve token
    assert ^token = TokenRepository.get_access_token(pid, "rsgaobZaE09V4OA8kQDkP9d3pn-KCw5aTTR8pcf_Mw8")

    # Non-existent token returns nil
    assert nil == TokenRepository.get_access_token(pid, "nonexistent")
  end

  test "stores and retrieves refresh tokens", %{pid: pid} do
    token = %RefreshToken{
      refresh_token: "CE7Ct5rlJlbGi0e4tPQKUZpgavYc6wwgBFvLu2v_r-c",
      client_id: "oauth-client-1",
      scope: ["foo", "bar", "bazuka"]
    }

    # Store token
    assert {:ok, ^token} = TokenRepository.insert_refresh_token(pid, token)

    # Retrieve token
    assert ^token = TokenRepository.get_refresh_token(pid, "CE7Ct5rlJlbGi0e4tPQKUZpgavYc6wwgBFvLu2v_r-c")

    # Non-existent token returns nil
    assert nil == TokenRepository.get_refresh_token(pid, "nonexistent")
  end

  test "handles token deletion", %{pid: pid} do
    access_token = %AccessToken{
      access_token: "rsgaobZaE09V4OA8kQDkP9d3pn-KCw5aTTR8pcf_Mw8",
      client_id: "oauth-client-1",
      scope: ["foo", "bar", "bazuka"],
      expires_at: "2025-06-29T21:41:47.088Z"
    }

    refresh_token = %RefreshToken{
      refresh_token: "CE7Ct5rlJlbGi0e4tPQKUZpgavYc6wwgBFvLu2v_r-c",
      client_id: "oauth-client-1",
      scope: ["foo", "bar", "bazuka"]
    }

    # Store tokens
    assert {:ok, ^access_token} = TokenRepository.insert_access_token(pid, access_token)
    assert {:ok, ^refresh_token} = TokenRepository.insert_refresh_token(pid, refresh_token)

    # Delete access token
    assert {:ok, ^access_token} = TokenRepository.delete_access_token(pid, "rsgaobZaE09V4OA8kQDkP9d3pn-KCw5aTTR8pcf_Mw8")
    assert nil == TokenRepository.get_access_token(pid, "rsgaobZaE09V4OA8kQDkP9d3pn-KCw5aTTR8pcf_Mw8")
    # Try to delete the same access token again
    assert {:error, :not_found} = TokenRepository.delete_access_token(pid, "rsgaobZaE09V4OA8kQDkP9d3pn-KCw5aTTR8pcf_Mw8")
    # Refresh token should still exist
    assert ^refresh_token = TokenRepository.get_refresh_token(pid, "CE7Ct5rlJlbGi0e4tPQKUZpgavYc6wwgBFvLu2v_r-c")

    # Delete refresh token
    assert {:ok, ^refresh_token} = TokenRepository.delete_refresh_token(pid, "CE7Ct5rlJlbGi0e4tPQKUZpgavYc6wwgBFvLu2v_r-c")
    assert nil == TokenRepository.get_refresh_token(pid, "CE7Ct5rlJlbGi0e4tPQKUZpgavYc6wwgBFvLu2v_r-c")
    # Try to delete the same refresh token again
    assert {:error, :not_found} = TokenRepository.delete_refresh_token(pid, "CE7Ct5rlJlbGi0e4tPQKUZpgavYc6wwgBFvLu2v_r-c")
  end

  test "handles non-existent token deletion", %{pid: pid} do
    assert {:error, :not_found} = TokenRepository.delete_access_token(pid, "nonexistent")
    assert {:error, :not_found} = TokenRepository.delete_refresh_token(pid, "nonexistent")
  end

  test "stores multiple tokens for different clients", %{pid: pid} do
    access_token1 = %AccessToken{
      access_token: "rsgaobZaE09V4OA8kQDkP9d3pn-KCw5aTTR8pcf_Mw8",
      client_id: "oauth-client-1",
      scope: ["foo", "bar", "bazuka"],
      expires_at: "2025-06-29T21:41:47.088Z"
    }

    refresh_token1 = %RefreshToken{
      refresh_token: "CE7Ct5rlJlbGi0e4tPQKUZpgavYc6wwgBFvLu2v_r-c",
      client_id: "oauth-client-1",
      scope: ["foo", "bar", "bazuka"]
    }

    access_token2 = %AccessToken{
      access_token: "different-access-token",
      client_id: "oauth-client-2",
      scope: ["read", "write"],
      expires_at: "2025-06-29T21:41:47.088Z"
    }

    # Store tokens
    assert {:ok, ^access_token1} = TokenRepository.insert_access_token(pid, access_token1)
    assert {:ok, ^refresh_token1} = TokenRepository.insert_refresh_token(pid, refresh_token1)
    assert {:ok, ^access_token2} = TokenRepository.insert_access_token(pid, access_token2)

    # Verify retrieval by token values
    assert ^access_token1 = TokenRepository.get_access_token(pid, "rsgaobZaE09V4OA8kQDkP9d3pn-KCw5aTTR8pcf_Mw8")
    assert ^refresh_token1 = TokenRepository.get_refresh_token(pid, "CE7Ct5rlJlbGi0e4tPQKUZpgavYc6wwgBFvLu2v_r-c")
    assert ^access_token2 = TokenRepository.get_access_token(pid, "different-access-token")
  end
end
