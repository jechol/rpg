defmodule Rpg.MultiNodesTest do
  use ExUnit.Case

  for pg <- [:pg] do
    @pg pg

    setup %{test: test} do
      scope = test
      Cluster.ensure_other_node_started()

      {:ok, _pid} = @pg.start(scope)
      {:ok, _pid} = Cluster.rpc_other_node(@pg, :start, [scope])
      local_pid = self()
      remote_pid = ClusterUtil.spawn_on_other_node()

      {:ok, %{scope: scope, local_pid: local_pid, remote_pid: remote_pid}}
    end

    test "join, leave, get_members, get_local_members", %{
      scope: scope,
      local_pid: local_pid,
      remote_pid: remote_pid
    } do
      # Join from local
      :ok = @pg.join(scope, :group1, local_pid)
      # Join from remote
      :ok = Cluster.rpc_other_node(@pg, :join, [scope, :group1, remote_pid])

      # Check members are synced
      Process.sleep(200)
      assert @pg.get_members(scope, :group1) == [remote_pid, local_pid]
      assert @pg.get_local_members(scope, :group1) == [local_pid]
      assert Cluster.rpc_other_node(@pg, :get_local_members, [scope, :group1]) == [remote_pid]

      # Leave from local
      :ok = @pg.leave(scope, :group1, local_pid)
      # Leave from remote
      :ok = Cluster.rpc_other_node(@pg, :leave, [scope, :group1, remote_pid])

      # Check members are synced
      Process.sleep(200)
      assert @pg.get_members(scope, :group1) == []
      assert @pg.get_local_members(scope, :group1) == []
      assert Cluster.rpc_other_node(@pg, :get_local_members, [scope, :group1]) == []
    end

    test "restart remote", %{scope: scope, local_pid: local_pid} do
      # Join from local
      :ok = @pg.join(scope, :group1, local_pid)

      # Check remote is synced
      Process.sleep(200)
      assert Cluster.rpc_other_node(@pg, :get_members, [scope, :group1]) == [local_pid]

      # Kill remote scope
      # remote_scope_pid = Cluster.rpc_other_node(Process, :whereis, [scope])
      # true = Cluster.rpc_other_node(Process, :exit, [remote_scope_pid, :kill])

      scope_pid = Cluster.rpc_other_node(Process, :whereis, [scope])
      ref = Process.monitor(scope_pid)

      true = Process.exit(scope_pid, :kill)

      receive do
        {:DOWN, ^ref, :process, ^scope_pid, :killed} -> :ok
      end

      # get_members returns empty when scope is not started
      assert Cluster.rpc_other_node(@pg, :get_members, [scope, :group1]) == []

      # Restart remote scope and check remote is synced again
      {:ok, _new_scope_pid} = Cluster.rpc_other_node(@pg, :start, [scope])
      Process.sleep(200)
      assert Cluster.rpc_other_node(@pg, :get_members, [scope, :group1]) == [local_pid]
    end

    test "restart local", %{scope: scope, remote_pid: remote_pid} do
      # Join from remote
      :ok = Cluster.rpc_other_node(@pg, :join, [scope, :group1, remote_pid])
      assert Cluster.rpc_other_node(@pg, :get_members, [scope, :group1]) == [remote_pid]

      # Check local is synced
      Process.sleep(200)
      assert @pg.get_members(scope, :group1) == [remote_pid]

      # Kill local scope
      scope_pid = Process.whereis(scope)
      ref = Process.monitor(scope_pid)

      true = Process.exit(scope_pid, :kill)

      receive do
        {:DOWN, ^ref, :process, ^scope_pid, :killed} -> :ok
      end

      # get_members return empty when scope is not started
      assert @pg.get_members(scope, :group1) == []

      # Restart local scope and check local is synced again
      {:ok, _new_scope_pid} = @pg.start(scope)
      Process.sleep(200)
      assert @pg.get_members(scope, :group1) == [remote_pid]
    end
  end
end
