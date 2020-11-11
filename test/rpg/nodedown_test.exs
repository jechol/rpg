defmodule Rpg.NodeDownTest do
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

    test "remote members are removed when remote node is down", %{
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

      Cluster.stop_other_node()

      # Check remote members are removed
      Process.sleep(200)
      assert @pg.get_members(scope, :group1) == [local_pid]
    end
  end
end
