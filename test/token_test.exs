defmodule SimpleISAM.TokenTest do
  use ExUnit.Case
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

  setup do
    # Create a temporary directory for test files
    tmp_dir = Path.join([System.tmp_dir!(), "simple_isam_test", to_string(:rand.uniform(1000000))])
    File.mkdir_p!(tmp_dir)
    test_file = Path.join(tmp_dir, "tokens.ndjson")

    # Start SimpleISAM with the test file
    {:ok, pid} = SimpleISAM.start_link(
      file_path: test_file,
      key_fields: [:access_token, :refresh_token],
      struct_type: AccessToken
    )

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    %{pid: pid, test_file: test_file}
  end

  test "stores and retrieves different token types", %{pid: pid} do
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

    assert {:ok, ^access_token} = SimpleISAM.insert(pid, access_token)
    assert {:ok, ^refresh_token} = SimpleISAM.insert(pid, refresh_token)

    assert ^access_token = SimpleISAM.get(pid, :access_token, access_token.access_token)
    assert ^refresh_token = SimpleISAM.get(pid, :refresh_token, refresh_token.refresh_token)
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

    assert {:ok, ^access_token} = SimpleISAM.insert(pid, access_token)
    assert {:ok, ^refresh_token} = SimpleISAM.insert(pid, refresh_token)

    assert {:ok, _} = SimpleISAM.delete(pid, :access_token, access_token.access_token)
    assert nil == SimpleISAM.get(pid, :access_token, access_token.access_token)
    assert ^refresh_token = SimpleISAM.get(pid, :refresh_token, refresh_token.refresh_token)
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

    assert {:ok, ^access_token1} = SimpleISAM.insert(pid, access_token1)
    assert {:ok, ^refresh_token1} = SimpleISAM.insert(pid, refresh_token1)
    assert {:ok, ^access_token2} = SimpleISAM.insert(pid, access_token2)

    assert ^access_token1 = SimpleISAM.get(pid, :access_token, access_token1.access_token)
    assert ^refresh_token1 = SimpleISAM.get(pid, :refresh_token, refresh_token1.refresh_token)
    assert ^access_token2 = SimpleISAM.get(pid, :access_token, access_token2.access_token)
  end
end
