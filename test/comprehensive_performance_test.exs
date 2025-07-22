defmodule SimpleISAM.ComprehensivePerformanceTest do
  use ExUnit.Case
  require Logger

  test "comprehensive buffer size performance comparison" do
    buffer_sizes = [5, 10, 20, 50, 100, 500]

    # Test simple records
    simple_results = Enum.map(buffer_sizes, fn buffer_size ->
      run_simple_performance_test(buffer_size)
    end)

    # Test client records
    client_results = Enum.map(buffer_sizes, fn buffer_size ->
      run_client_performance_test(buffer_size)
    end)

    # Test token records
    token_results = Enum.map(buffer_sizes, fn buffer_size ->
      run_token_performance_test(buffer_size)
    end)

    # Find best performing buffer size for each type
    best_simple = List.first(Enum.sort_by(simple_results, & &1.writes_per_sec, :desc))
    best_client = List.first(Enum.sort_by(client_results, & &1.writes_per_sec, :desc))
    best_token = List.first(Enum.sort_by(token_results, & &1.writes_per_sec, :desc))

    Logger.info("""
    Comprehensive Buffer Size Performance Comparison:
    ================================================

    SIMPLE RECORDS (small):
    #{format_results(simple_results)}
    Best: #{best_simple.buffer_size} records (#{:erlang.float_to_binary(best_simple.writes_per_sec, decimals: 0)} writes/sec)

    CLIENT RECORDS (medium):
    #{format_results(client_results)}
    Best: #{best_client.buffer_size} records (#{:erlang.float_to_binary(best_client.writes_per_sec, decimals: 0)} writes/sec)

    TOKEN RECORDS (large):
    #{format_results(token_results)}
    Best: #{best_token.buffer_size} records (#{:erlang.float_to_binary(best_token.writes_per_sec, decimals: 0)} writes/sec)

    SUMMARY:
    - Simple records: #{best_simple.buffer_size} records optimal
    - Client records: #{best_client.buffer_size} records optimal
    - Token records: #{best_token.buffer_size} records optimal
    """)
  end

  defp run_simple_performance_test(buffer_size) do
    test_file = Path.join(System.tmp_dir!(), "simple_isam_simple_test_#{buffer_size}.ndjson")
    File.rm(test_file)

    {:ok, pid} = SimpleISAM.start_link(
      file_path: test_file,
      key_fields: [:id],
      buffer_size: buffer_size
    )

    records = for i <- 1..10_000 do
      %{
        id: "record_#{i}",
        data: "some data for record #{i}",
        timestamp: System.system_time(:millisecond)
      }
    end

    {time_sec, writes_per_sec, ns_per_write} = measure_writes(pid, records)

    GenServer.stop(pid)
    File.rm(test_file)

    %{
      buffer_size: buffer_size,
      total_time_sec: time_sec,
      writes_per_sec: writes_per_sec,
      ns_per_write: ns_per_write,
      record_type: "simple"
    }
  end

  defp run_client_performance_test(buffer_size) do
    test_file = Path.join(System.tmp_dir!(), "simple_isam_client_test_#{buffer_size}.ndjson")
    File.rm(test_file)

    {:ok, pid} = ClientRepository.start_link(
      file_path: test_file,
      buffer_size: buffer_size
    )

    records = for i <- 1..10_000 do
      %ClientRepository.OAuthClient{
        client_id: "client_#{i}",
        client_secret: "secret_#{i}_#{:crypto.strong_rand_bytes(32) |> Base.encode64()}",
        name: "Test Client #{i}",
        redirect_uris: ["https://example#{i}.com/callback", "https://app#{i}.com/oauth/callback"],
        scopes: ["read", "write", "admin", "profile", "email"]
      }
    end

    {time_sec, writes_per_sec, ns_per_write} = measure_client_writes(pid, records)

    GenServer.stop(pid)
    File.rm(test_file)

    %{
      buffer_size: buffer_size,
      total_time_sec: time_sec,
      writes_per_sec: writes_per_sec,
      ns_per_write: ns_per_write,
      record_type: "client"
    }
  end

  defp run_token_performance_test(buffer_size) do
    test_file = Path.join(System.tmp_dir!(), "simple_isam_token_test_#{buffer_size}.ndjson")
    File.rm(test_file)

    {:ok, pid} = TokenRepository.start_link(
      file_path: test_file,
      buffer_size: buffer_size
    )

    records = for i <- 1..10_000 do
      %TokenRepository.AccessToken{
        access_token: "access_token_#{i}_#{:crypto.strong_rand_bytes(32) |> Base.encode64()}",
        client_id: "client_#{i}",
        scope: "read write admin profile email",
        expires_at: System.system_time(:second) + 3600
      }
    end

    {time_sec, writes_per_sec, ns_per_write} = measure_token_writes(pid, records)

    GenServer.stop(pid)
    File.rm(test_file)

    %{
      buffer_size: buffer_size,
      total_time_sec: time_sec,
      writes_per_sec: writes_per_sec,
      ns_per_write: ns_per_write,
      record_type: "token"
    }
  end

  defp measure_writes(pid, records) do
    start_time = System.monotonic_time(:nanosecond)

    Enum.each(records, fn record ->
      {:ok, _} = SimpleISAM.insert(pid, record)
    end)

    end_time = System.monotonic_time(:nanosecond)
    calculate_metrics(start_time, end_time, length(records))
  end

  defp measure_client_writes(pid, records) do
    start_time = System.monotonic_time(:nanosecond)

    Enum.each(records, fn record ->
      {:ok, _} = ClientRepository.register_client(pid, record)
    end)

    end_time = System.monotonic_time(:nanosecond)
    calculate_metrics(start_time, end_time, length(records))
  end

  defp measure_token_writes(pid, records) do
    start_time = System.monotonic_time(:nanosecond)

    Enum.each(records, fn record ->
      {:ok, _} = TokenRepository.insert_access_token(pid, record)
    end)

    end_time = System.monotonic_time(:nanosecond)
    calculate_metrics(start_time, end_time, length(records))
  end

  defp calculate_metrics(start_time, end_time, count) do
    total_time_ns = end_time - start_time
    total_time_sec = total_time_ns / 1_000_000_000
    writes_per_sec = count / total_time_sec
    ns_per_write = total_time_ns / count

    {total_time_sec, writes_per_sec, ns_per_write}
  end

  defp format_results(results) do
    results
    |> Enum.map(fn result ->
      """
        Buffer: #{result.buffer_size} records
          Time: #{:erlang.float_to_binary(result.total_time_sec, decimals: 3)}s
          Writes/sec: #{:erlang.float_to_binary(result.writes_per_sec, decimals: 0)}
          ns/write: #{:erlang.float_to_binary(result.ns_per_write, decimals: 0)}
      """
    end)
    |> Enum.join("\n")
  end
end
