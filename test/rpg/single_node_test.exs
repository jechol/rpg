defmodule Rpg.SingleNodeTest do
  @moduledoc false

  use ExUnit.Case
  doctest Rpg

  setup do
    ClusterUtil.restart_cur_node(:rpg)
  end

  test "initial state" do
    assert Rpg.which_groups() == []
  end

  test "create group" do
    :ok = Rpg.create(:test_group)

    assert Rpg.which_groups() == [:test_group]
  end

  test "delete group" do
    :ok = Rpg.create(:test_group)
    :ok = Rpg.delete(:test_group)

    assert Rpg.which_groups() == []
  end

  test "join group" do
    :ok = Rpg.create(:test_group)
    :ok = Rpg.join(:test_group, self())

    assert Rpg.get_members(:test_group) == [self()]
    assert Rpg.get_local_members(:test_group) == [self()]
    assert Rpg.get_closest_pid(:test_group) == self()
  end

  test "leave group" do
    :ok = Rpg.create(:test_group)

    :ok = Rpg.join(:test_group, self())
    :ok = Rpg.leave(:test_group, self())

    assert Rpg.get_members(:test_group) == []
    assert Rpg.get_local_members(:test_group) == []
    assert Rpg.get_closest_pid(:test_group) == {:error, {:no_process, :test_group}}
  end

  test "get closest pid returns random member" do
    :rand.seed(:exsplus, {0, 0, 1})

    assert Rpg.get_closest_pid(:test_group) == {:error, {:no_such_group, :test_group}}

    other_pid =
      spawn_link(fn ->
        Process.sleep(:infinity)
      end)

    :ok = Rpg.create(:test_group)
    :ok = Rpg.join(:test_group, self())
    :ok = Rpg.join(:test_group, other_pid)

    assert Rpg.get_closest_pid(:test_group) == self()
    assert Rpg.get_closest_pid(:test_group) == other_pid
  end

  test "member dies" do
    other_pid =
      spawn_link(fn ->
        receive do
          :exit -> :ok
        end
      end)

    :ok = Rpg.create(:test_group)
    :ok = Rpg.join(:test_group, other_pid)

    assert Rpg.get_closest_pid(:test_group) == other_pid

    send(other_pid, :exit)
    # We should wait enough for pg2 to process 'DOWN'
    Process.sleep(100)

    assert Rpg.get_closest_pid(:test_group) == {:error, {:no_process, :test_group}}
  end

  test "worker should log unexpected calls" do
    assert ExUnit.CaptureLog.capture_log(fn ->
             catch_exit(GenServer.call(Rpg.Worker, :unexpected_message))
           end) =~
             "The Rpg server received an unexpected message:\nhandle_call(:unexpected_message"
  end
end
