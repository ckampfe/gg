defmodule GgTest.Example do
  def id(initial) do
    initial
  end

  def plus_1(x) do
    x + 1
  end

  def plus_5(x) do
    x + 5
  end

  def minus_2(x) do
    x - 2
  end

  def add(x, y) do
    x + y
  end
end

defmodule GgTest do
  use ExUnit.Case
  doctest Gg
  import GgTest.Example

  test "greets the world" do
    comp =
      Gg.compile(%{
        a: fn %{args: args} -> id(args) end,
        e: fn %{c: c, d: d} -> add(c, d) end,
        c: fn %{b: b} -> minus_2(b) end,
        b: fn %{a: a} -> plus_1(a) end,
        d: fn %{c: c} -> plus_5(c) end
      })

    assert comp.(%{args: 7}) == %{
             a: 7,
             b: 8,
             c: 6,
             d: 11,
             e: 17
           }
  end

  test "greets the world async" do
    comp =
      Gg.compile_async(%{
        a: fn %{args: args} -> id(args) end,
        e: fn %{c: c, d: d} -> add(c, d) end,
        c: fn %{b: b} -> minus_2(b) end,
        b: fn %{a: a} -> plus_1(a) end,
        d: fn %{c: c} -> plus_5(c) end
      })

    assert Task.await(comp.(%{args: 7})) == %{
             a: 7,
             b: 8,
             c: 6,
             d: 11,
             e: 17
           }
  end

  test "async runs stages in parallel" do
    comp =
      Gg.compile(%{
        begin: fn %{args: _} -> :ok end,
        a: fn %{begin: _} -> :timer.sleep(50) end,
        b: fn %{begin: _} -> :timer.sleep(50) end,
        c: fn %{a: _, b: _} -> :ok end
      })

    comp_async =
      Gg.compile_async(%{
        begin: fn %{args: _} -> :ok end,
        a: fn %{begin: _} -> :timer.sleep(50) end,
        b: fn %{begin: _} -> :timer.sleep(50) end,
        c: fn %{a: _, b: _} -> :ok end
      })

    {sync_micros, _results_sync} = :timer.tc(fn -> comp.(%{args: %{}}) end)
    {async_micros, _results_async} = :timer.tc(fn -> Task.await(comp_async.(%{args: %{}})) end)

    epsilon_micros = 1500

    assert async_micros > sync_micros / 2 - epsilon_micros &&
             async_micros < sync_micros / 2 + epsilon_micros
  end

  test "topological order" do
    ordering =
      Gg.topological_order(%{
        a: fn %{args: args} -> id(args) end,
        e: fn %{c: c, d: d} -> add(c, d) end,
        c: fn %{b: b} -> minus_2(b) end,
        b: fn %{a: a} -> plus_1(a) end,
        d: fn %{c: c} -> plus_5(c) end
      })

    assert ordering == [:args, :a, :b, :c, :d, :e]
  end

  test "to dot" do
    result =
      Gg.visualize(%{
        a: fn %{args: args} -> id(args) end,
        e: fn %{c: c, d: d} -> add(c, d) end,
        c: fn %{b: b} -> minus_2(b) end,
        b: fn %{a: a} -> plus_1(a) end,
        d: fn %{c: c} -> plus_5(c) end
      })

    assert {:ok, dot} = result

    File.write!("out.dot", dot)
  end
end
