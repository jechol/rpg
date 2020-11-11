defmodule Rpg.MultiNodesTest do
  use ExUnit.Case

  for pg <- [:pg] do
    @pg pg

    setup %{test: test} do
      Cluster.ensure_other_node_started()

      {:ok, _pid} = @pg.start_link(test)
      {:ok, _pid} = Cluster.rpc_other_node(@pg, :start_link, [test])
      {:ok, %{scope: test}}
    end

    test "nodes share groups", %{scope: scope} do
      :ok = @pg.join(scope, :test_group, self())
      assert_group_membership(scope, :test_group, self())

      remote_pid = ClusterUtil.spawn_on_other_node()
      :ok = Cluster.rpc_other_node(@pg, :join, [scope, :test_group2, remote_pid])
      assert_group_membership(scope, :test_group2, remote_pid)

      :ok = @pg.leave(scope, :test_group, self())
      assert_no_group_member(scope, :test_group)

      :ok = Cluster.rpc_other_node(@pg, :leave, [scope, :test_group2, remote_pid])
      assert_no_group_member(scope, :test_group2)
    end

    test "reset remote", %{scope: scope} do
      :ok = @pg.create(scope, :test_group)
      :ok = @pg.join(scope, :test_group, self())
      assert_group_membership(scope, :test_group, self())

      ClusterUtil.restart_other_node(:rpg)
      # Wait for newly created remote pg2 to sync
      Process.sleep(1_000)

      assert_group_membership(scope, :test_group, self())
    end

    test "reset local", %{scope: scope} do
      remote_pid = ClusterUtil.spawn_on_other_node()

      :ok = Cluster.rpc_other_node(@pg, :create, [:test_group])
      :ok = Cluster.rpc_other_node(@pg, :join, [:test_group, remote_pid])

      assert_group_membership(scope, :test_group, remote_pid)

      ClusterUtil.restart_cur_node(:rpg)
      Process.sleep(1_000)

      assert_group_membership(scope, :test_group, remote_pid)
    end

    defp assert_group_membership(scope, group, pid) do
      this_node = node()

      {local_members, remote_members} =
        case node(pid) do
          ^this_node -> {[pid], []}
          _ -> {[], [pid]}
        end

      assert @pg.get_members(scope, group) == [pid]
      assert @pg.get_local_members(scope, group) == local_members

      # Wait for pg to sync
      Process.sleep(300)

      assert Cluster.rpc_other_node(@pg, :get_members, [scope, group]) == [pid]
      assert Cluster.rpc_other_node(@pg, :get_local_members, [scope, group]) == remote_members
    end

    defp assert_no_group_member(scope, group) do
      assert @pg.get_members(scope, group) == []
      assert @pg.get_local_members(scope, group) == []

      assert Cluster.rpc_other_node(@pg, :get_members, [scope, group]) == []
      assert Cluster.rpc_other_node(@pg, :get_local_members, [scope, group]) == []
    end
  end
end
