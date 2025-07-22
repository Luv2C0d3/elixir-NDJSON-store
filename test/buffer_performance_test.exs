defmodule SimpleISAM.BufferPerformanceTest do
  use ExUnit.Case
  require Logger

    test "buffer size performance comparison" do
    buffer_sizes = [5, 10, 20, 50, 100, 500]

    results = Enum.map(buffer_sizes, fn buffer_size ->
      run_performance_test(buffer_size)
    end)

    # Sort results by writes/sec (descending)
    sorted_results = Enum.sort_by(results, & &1.writes_per_sec, :desc)

    Logger.info("""
    Buffer Size Performance Comparison:
    ==================================
    #{format_results(sorted_results)}

    Best performing buffer size: #{List.first(sorted_results).buffer_size} records
    """)
  end

  defp run_performance_test(buffer_size) do
    # Setup
    test_file = Path.join(System.tmp_dir!(), "simple_isam_buffer_test_#{buffer_size}.ndjson")
    File.rm(test_file)

    {:ok, pid} = SimpleISAM.start_link(
      file_path: test_file,
      key_fields: [:id],
      buffer_size: buffer_size
    )

    # Test data - 10k records
    records = for i <- 1..10_000 do
      %{
        id: "record_#{i}",
        data: "some data for record #{i}",
        timestamp: System.system_time(:millisecond)
      }
    end

    # Measure write performance
    start_time = System.monotonic_time(:nanosecond)

    Enum.each(records, fn record ->
      {:ok, _} = SimpleISAM.insert(pid, record)
    end)

    end_time = System.monotonic_time(:nanosecond)

    # Calculate metrics
    total_time_ns = end_time - start_time
    total_time_sec = total_time_ns / 1_000_000_000
    writes_per_sec = 10_000 / total_time_sec
    ns_per_write = total_time_ns / 10_000

    # Cleanup
    GenServer.stop(pid)
    File.rm(test_file)

    %{
      buffer_size: buffer_size,
      total_time_sec: total_time_sec,
      writes_per_sec: writes_per_sec,
      ns_per_write: ns_per_write
    }
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
