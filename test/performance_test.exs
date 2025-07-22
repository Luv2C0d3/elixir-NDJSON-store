defmodule SimpleISAM.PerformanceTest do
  use ExUnit.Case
  require Logger

  test "write performance - 10k entries" do
    # Setup
    test_file = Path.join(System.tmp_dir!(), "simple_isam_perf_test.ndjson")
    File.rm(test_file)

    {:ok, pid} = SimpleISAM.start_link(
      file_path: test_file,
      key_fields: [:id]
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

    # Log results
    Logger.info("""
    SimpleISAM Performance Test Results:
    ===================================
    Total records: 10,000
    Total time: #{:erlang.float_to_binary(total_time_sec, decimals: 3)}s
    Writes/sec: #{:erlang.float_to_binary(writes_per_sec, decimals: 0)}
    ns/write: #{:erlang.float_to_binary(ns_per_write, decimals: 0)}
    """)

    # Verify all records were written
    assert File.exists?(test_file)
    file_size = File.stat!(test_file).size
    assert file_size > 0

    # Cleanup
    GenServer.stop(pid)
    File.rm(test_file)
  end

  test "read performance after 10k writes" do
    # Setup
    test_file = Path.join(System.tmp_dir!(), "simple_isam_read_perf_test.ndjson")
    File.rm(test_file)

    {:ok, pid} = SimpleISAM.start_link(
      file_path: test_file,
      key_fields: [:id]
    )

    # Write 10k records
    records = for i <- 1..10_000 do
      %{
        id: "record_#{i}",
        data: "some data for record #{i}",
        timestamp: System.system_time(:millisecond)
      }
    end

    Enum.each(records, fn record ->
      {:ok, _} = SimpleISAM.insert(pid, record)
    end)

        # Measure read performance
    start_time = System.monotonic_time(:nanosecond)

    Enum.each(1..10_000, fn i ->
      SimpleISAM.get(pid, :id, "record_#{i}")
    end)

    end_time = System.monotonic_time(:nanosecond)

    # Calculate metrics
    total_time_ns = end_time - start_time
    total_time_sec = total_time_ns / 1_000_000_000
    reads_per_sec = 10_000 / total_time_sec
    ns_per_read = total_time_ns / 10_000

    # Log results
    Logger.info("""
    SimpleISAM Read Performance Test Results:
    ========================================
    Total reads: 10,000
    Total time: #{:erlang.float_to_binary(total_time_sec, decimals: 3)}s
    Reads/sec: #{:erlang.float_to_binary(reads_per_sec, decimals: 0)}
    ns/read: #{:erlang.float_to_binary(ns_per_read, decimals: 0)}
    """)

    # Cleanup
    GenServer.stop(pid)
    File.rm(test_file)
  end
end
