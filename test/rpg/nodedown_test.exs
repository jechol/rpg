defmodule Rpg.NodeDownTest do
  @moduledoc false

  use ExUnit.Case

  alias ClusterUtil

  setup do
    ClusterUtil.restart_cluster(:rpg)
    :ok
  end

  test "join remote_pid from already dead node to local pg2" do
    :ok = Rpg.create(:test_group)

    remote_pid = ClusterUtil.spawn_on_other_node()

    :ok = Cluster.stop_other_node()
    :ok = Rpg.join(:test_group, remote_pid)

    Process.sleep(1_000)
    assert Rpg.get_members(:test_group) == []
  end
end
