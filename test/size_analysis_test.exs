defmodule SimpleISAM.SizeAnalysisTest do
  use ExUnit.Case
  require Logger

  test "analyze record sizes and buffer durability" do
    # Generate sample records
    simple_record = %{
      id: "record_1",
      data: "some data for record 1",
      timestamp: System.system_time(:millisecond)
    }

    client_record = %ClientRepository.OAuthClient{
      client_id: "client_1",
      client_secret: "secret_1_#{:crypto.strong_rand_bytes(32) |> Base.encode64()}",
      name: "Test Client 1",
      redirect_uris: ["https://example1.com/callback", "https://app1.com/oauth/callback"],
      scopes: ["read", "write", "admin", "profile", "email"]
    }

    token_record = %TokenRepository.AccessToken{
      access_token: "access_token_1_#{:crypto.strong_rand_bytes(32) |> Base.encode64()}",
      client_id: "client_1",
      scope: "read write admin profile email",
      expires_at: System.system_time(:second) + 3600
    }

    # Calculate JSON sizes
    simple_json = Jason.encode!(simple_record) <> "\n"
    client_json = Jason.encode!(Map.from_struct(client_record)) <> "\n"
    token_json = Jason.encode!(Map.from_struct(token_record)) <> "\n"

    simple_size = byte_size(simple_json)
    client_size = byte_size(client_json)
    token_size = byte_size(token_json)

    # Calculate buffer sizes for recommended configurations
    simple_buffer_bytes = simple_size * 50
    client_buffer_bytes = client_size * 20
    token_buffer_bytes = token_size * 10

    Logger.info("""
    Record Size Analysis:
    ====================

    Individual Record Sizes:
    - Simple record: #{simple_size} bytes
    - Client record: #{client_size} bytes
    - Token record: #{token_size} bytes

    Recommended Buffer Configurations:
    - Simple: 50 records = #{simple_buffer_bytes} bytes (#{:erlang.float_to_binary(simple_buffer_bytes / 1024, decimals: 1)} KB)
    - Client: 20 records = #{client_buffer_bytes} bytes (#{:erlang.float_to_binary(client_buffer_bytes / 1024, decimals: 1)} KB)
    - Token: 10 records = #{token_buffer_bytes} bytes (#{:erlang.float_to_binary(token_buffer_bytes / 1024, decimals: 1)} KB)

    Durability Trade-off Summary:
    - Simple records: #{simple_buffer_bytes} bytes potential loss (50 records)
    - Client records: #{client_buffer_bytes} bytes potential loss (20 records)
    - Token records: #{token_buffer_bytes} bytes potential loss (10 records)

    JSON Examples:
    Simple: #{simple_json |> String.trim()}
    Client: #{client_json |> String.trim()}
    Token: #{token_json |> String.trim()}
    """)
  end
end
