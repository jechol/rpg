defmodule Rpg.MultiNodesTest do
  @moduledoc false

  use ExUnit.Case

  setup do
    Cluster.ensure_other_node_started()
    ClusterUtil.restart_cluster(:rpg)
    :ok
  end

  test "nodes share groups" do
    :ok = Rpg.create(:test_group)
    :ok = Rpg.join(:test_group, self())
    assert_group_membership(:test_group, self())

    remote_pid = ClusterUtil.spawn_on_other_node()
    :ok = Cluster.rpc_other_node(Rpg, :create, [:test_group2])
    :ok = Cluster.rpc_other_node(Rpg, :join, [:test_group2, remote_pid])
    assert_group_membership(:test_group2, remote_pid)

    :ok = Rpg.leave(:test_group, self())
    assert_no_group_member(:test_group)

    :ok = Cluster.rpc_other_node(Rpg, :leave, [:test_group2, remote_pid])
    assert_no_group_member(:test_group2)
  end

  test "reset remote" do
    :ok = Rpg.create(:test_group)
    :ok = Rpg.join(:test_group, self())
    assert_group_membership(:test_group, self())

    ClusterUtil.restart_other_node(:rpg)
    # Wait for newly created remote pg2 to sync
    Process.sleep(1_000)

    assert_group_membership(:test_group, self())
  end

  test "reset local" do
    remote_pid = ClusterUtil.spawn_on_other_node()

    :ok = Cluster.rpc_other_node(Rpg, :create, [:test_group])
    :ok = Cluster.rpc_other_node(Rpg, :join, [:test_group, remote_pid])

    assert_group_membership(:test_group, remote_pid)

    ClusterUtil.restart_cur_node(:rpg)
    Process.sleep(1_000)

    assert_group_membership(:test_group, remote_pid)
  end

  defp assert_group_membership(name, pid) do
    this_node = node()

    {local_pid, remote_pid} =
      case node(pid) do
        ^this_node -> {[pid], []}
        _ -> {[], [pid]}
      end

    assert Rpg.get_members(name) == [pid]
    assert Rpg.get_local_members(name) == local_pid
    assert Rpg.get_closest_pid(name) == pid

    assert Cluster.rpc_other_node(Rpg, :get_members, [name]) == [pid]
    assert Cluster.rpc_other_node(Rpg, :get_local_members, [name]) == remote_pid
    assert Cluster.rpc_other_node(Rpg, :get_closest_pid, [name]) == pid
  end

  defp assert_no_group_member(name) do
    assert Rpg.get_members(name) == []
    assert Rpg.get_local_members(name) == []
    assert Rpg.get_closest_pid(name) == {:error, {:no_process, name}}

    assert Cluster.rpc_other_node(Rpg, :get_members, [name]) == []
    assert Cluster.rpc_other_node(Rpg, :get_local_members, [name]) == []

    assert Cluster.rpc_other_node(Rpg, :get_closest_pid, [name]) ==
             {:error, {:no_process, name}}
  end
end
