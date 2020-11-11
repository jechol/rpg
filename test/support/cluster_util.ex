defmodule ClusterUtil do
  @moduledoc false

  def restart_cluster(app) do
    for cmd <- [:stop, :start] do
      for cur_node <- [node(), Cluster.other_node()] do
        :rpc.call(cur_node, Application, cmd, [app])
      end
    end

    :ok
  end

  def restart_other_node(app) do
    :ok = Cluster.rpc_other_node(__MODULE__, :restart_cur_node, [app])
  end

  def restart_cur_node(app) do
    :ok = Application.stop(app)
    :ok = Application.start(app)
  end
end
