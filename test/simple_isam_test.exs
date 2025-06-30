defmodule SimpleISAMTest do
  use ExUnit.Case
  alias SimpleISAM
  require Logger

  setup_all do
    # Enable debug logging during tests
    Logger.configure(level: :debug)
    :ok
  end

  defmodule User do
    defstruct [:id, :name, :email]
  end

  setup do
    # Create a temporary directory for test files
    tmp_dir = Path.join([System.tmp_dir!(), "simple_isam_test", to_string(:rand.uniform(1000000))])
    File.mkdir_p!(tmp_dir)
    test_file = Path.join(tmp_dir, "test.ndjson")

    # Start SimpleISAM with the test file
    {:ok, pid} = SimpleISAM.start_link(
      file_path: test_file,
      key_fields: [:id],
      struct_type: User
    )

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    %{pid: pid, test_file: test_file}
  end

  test "stores and retrieves records", %{pid: pid} do
    user = %User{id: "user-1", name: "John Doe", email: "john@example.com"}
    assert {:ok, ^user} = SimpleISAM.insert(pid, user)
    assert ^user = SimpleISAM.get(pid, :id, "user-1")
  end

  test "returns nil for non-existent records", %{pid: pid} do
    assert nil == SimpleISAM.get(pid, :id, "nonexistent")
  end

  test "updates existing records", %{pid: pid} do
    user = %User{id: "user-1", name: "John Doe", email: "john@example.com"}
    assert {:ok, ^user} = SimpleISAM.insert(pid, user)

    updated_user = %User{id: "user-1", name: "John Smith", email: "john.smith@example.com"}
    assert {:ok, ^updated_user} = SimpleISAM.insert(pid, updated_user)
    assert ^updated_user = SimpleISAM.get(pid, :id, "user-1")
  end

  test "deletes records", %{pid: pid} do
    user = %User{id: "user-1", name: "John Doe", email: "john@example.com"}
    assert {:ok, ^user} = SimpleISAM.insert(pid, user)
    assert :ok = SimpleISAM.delete(pid, :id, "user-1")
    assert nil == SimpleISAM.get(pid, :id, "user-1")
  end

  test "handles non-existent record deletion", %{pid: pid} do
    assert {:error, :not_found} = SimpleISAM.delete(pid, :id, "nonexistent")
  end
end
