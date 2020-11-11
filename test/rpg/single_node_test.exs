defmodule Rpg.SingleNodeTest do
  use ExUnit.Case

  for pg <- [:pg] do
    @pg pg

    setup %{test: test} do
      {:ok, _pid} = @pg.start_link(test)
      :ok
    end

    test "initial state", %{test: test} do
      assert @pg.which_groups(test) == []
    end

    test "join group", %{test: test} do
      :ok = @pg.join(test, :test_group, self())
      assert @pg.get_members(test, :test_group) == [self()]
      assert @pg.get_local_members(test, :test_group) == [self()]

      :ok = @pg.join(test, :test_group, self())
      assert @pg.get_members(test, :test_group) == [self(), self()]
      assert @pg.get_local_members(test, :test_group) == [self(), self()]

      pid = spawn_link(Process, :sleep, [:infinity])
      :ok = @pg.join(test, :test_group, pid)
      assert @pg.get_members(test, :test_group) == [pid, self(), self()]
      assert @pg.get_local_members(test, :test_group) == [pid, self(), self()]
    end

    test "leave group", %{test: test} do
      :ok = @pg.join(test, :test_group, self())
      :ok = @pg.leave(test, :test_group, self())

      assert @pg.get_members(test, :test_group) == []
      assert @pg.get_local_members(test, :test_group) == []
    end

    test "member dies", %{test: test} do
      other_pid =
        spawn_link(fn ->
          receive do
            :exit -> :ok
          end
        end)

      :ok = @pg.join(test, :test_group, other_pid)
      assert @pg.get_members(test, :test_group) == [other_pid]

      send(other_pid, :exit)
      Process.sleep(100)
      assert @pg.get_members(test, :test_group) == []
    end
  end
end
