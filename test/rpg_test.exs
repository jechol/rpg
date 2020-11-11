defmodule PGTest do
  @moduledoc false

  use ExUnit.Case

  setup do
    ClusterUtil.restart_cur_node(:pg2)
  end

  test "initial state" do
    assert :pg.which_groups() == []
  end

  test "create group" do
    :ok = :pg.create(:test_group)

    assert :pg.which_groups() == [:test_group]
  end

  test "delete group" do
    :ok = :pg.create(:test_group)
    :ok = :pg.delete(:test_group)

    assert :pg.which_groups() == []
  end

  test "join group" do
    :ok = :pg.create(:test_group)
    :ok = :pg.join(:test_group, self())

    assert :pg.get_members(:test_group) == [self()]
    assert :pg.get_local_members(:test_group) == [self()]
    assert :pg.get_closest_pid(:test_group) == self()
  end

  test "leave group" do
    :ok = :pg.create(:test_group)

    :ok = :pg.join(:test_group, self())
    :ok = :pg.leave(:test_group, self())

    assert :pg.get_members(:test_group) == []
    assert :pg.get_local_members(:test_group) == []
    assert :pg.get_closest_pid(:test_group) == {:error, {:no_process, :test_group}}
  end

  test "get closest pid returns random member" do
    :rand.seed(:exsplus, {0, 0, 1})

    assert :pg.get_closest_pid(:test_group) == {:error, {:no_such_group, :test_group}}

    other_pid =
      spawn_link(fn ->
        Process.sleep(:infinity)
      end)

    :ok = :pg.create(:test_group)
    :ok = :pg.join(:test_group, self())
    :ok = :pg.join(:test_group, other_pid)

    assert :pg.get_closest_pid(:test_group) == self()
    assert :pg.get_closest_pid(:test_group) == other_pid
  end

  test "member dies" do
    other_pid =
      spawn_link(fn ->
        receive do
          :exit -> :ok
        end
      end)

    :ok = :pg.create(:test_group)
    :ok = :pg.join(:test_group, other_pid)

    assert :pg.get_closest_pid(:test_group) == other_pid

    send(other_pid, :exit)
    # We should wait enough for pg2 to process 'DOWN'
    Process.sleep(100)

    assert :pg.get_closest_pid(:test_group) == {:error, {:no_process, :test_group}}
  end

  test "worker should log unexpected calls" do
    assert ExUnit.CaptureLog.capture_log(fn ->
             catch_exit(GenServer.call(:pg.Worker, :unexpected_message))
           end) =~
             "The :pg server received an unexpected message:\nhandle_call(:unexpected_message"
  end
end
