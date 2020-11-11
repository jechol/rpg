defmodule RePG2.SingleNodeTest do
  @moduledoc false

  use ExUnit.Case
  doctest RePG2

  setup do
    ClusterUtil.restart_cur_node(:repg2)
  end

  test "initial state" do
    assert RePG2.which_groups() == []
  end

  test "create group" do
    :ok = RePG2.create(:test_group)

    assert RePG2.which_groups() == [:test_group]
  end

  test "delete group" do
    :ok = RePG2.create(:test_group)
    :ok = RePG2.delete(:test_group)

    assert RePG2.which_groups() == []
  end

  test "join group" do
    :ok = RePG2.create(:test_group)
    :ok = RePG2.join(:test_group, self())

    assert RePG2.get_members(:test_group) == [self()]
    assert RePG2.get_local_members(:test_group) == [self()]
    assert RePG2.get_closest_pid(:test_group) == self()
  end

  test "leave group" do
    :ok = RePG2.create(:test_group)

    :ok = RePG2.join(:test_group, self())
    :ok = RePG2.leave(:test_group, self())

    assert RePG2.get_members(:test_group) == []
    assert RePG2.get_local_members(:test_group) == []
    assert RePG2.get_closest_pid(:test_group) == {:error, {:no_process, :test_group}}
  end

  test "get closest pid returns random member" do
    :rand.seed(:exsplus, {0, 0, 1})

    assert RePG2.get_closest_pid(:test_group) == {:error, {:no_such_group, :test_group}}

    other_pid =
      spawn_link(fn ->
        Process.sleep(:infinity)
      end)

    :ok = RePG2.create(:test_group)
    :ok = RePG2.join(:test_group, self())
    :ok = RePG2.join(:test_group, other_pid)

    assert RePG2.get_closest_pid(:test_group) == self()
    assert RePG2.get_closest_pid(:test_group) == other_pid
  end

  test "member dies" do
    other_pid =
      spawn_link(fn ->
        receive do
          :exit -> :ok
        end
      end)

    :ok = RePG2.create(:test_group)
    :ok = RePG2.join(:test_group, other_pid)

    assert RePG2.get_closest_pid(:test_group) == other_pid

    send(other_pid, :exit)
    # We should wait enough for pg2 to process 'DOWN'
    Process.sleep(100)

    assert RePG2.get_closest_pid(:test_group) == {:error, {:no_process, :test_group}}
  end

  test "worker should log unexpected calls" do
    assert ExUnit.CaptureLog.capture_log(fn ->
             catch_exit(GenServer.call(RePG2.Worker, :unexpected_message))
           end) =~
             "The RePG2 server received an unexpected message:\nhandle_call(:unexpected_message"
  end
end
