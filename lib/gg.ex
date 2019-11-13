defmodule Gg do
  defmacro compile(map) do
    graph = as_graph(map)
    node_ids = Graph.topsort(graph)

    quote do
      [args_id, first_node_id | _] = unquote(node_ids)

      %{^first_node_id => first_node} = unquote(map)

      fn args ->
        datamap = Map.put(unquote(map), first_node_id, first_node.(args))

        unquote(node_ids)
        |> Enum.drop(2)
        |> Enum.reduce(datamap, fn node_id, acc ->
          ins = Graph.in_neighbors(unquote(Macro.escape(graph)), node_id)
          deps = Map.take(acc, ins)
          node_fn = Map.fetch!(acc, node_id)
          Map.put(acc, node_id, node_fn.(deps))
        end)
      end
    end
  end

  defmacro visualize(map) do
    map
    |> as_graph()
    |> Graph.to_dot()
  end

  defmacro topological_order(map) do
    map
    |> as_graph()
    |> Graph.topsort()
  end

  def as_graph(map) do
    edges = Gg.compute_edges(map)

    Graph.new()
    |> Graph.add_edges(edges)
  end

  def compute_edges({:%{}, _position, kvs}) do
    Enum.flat_map(kvs, fn {fn_name,
                           {:fn, _fn_pos,
                            [
                              {:->, _arrow_pos,
                               [[{:%{}, _args_pos, args_keyword_list}] = _args, _body]}
                            ]}} ->
      Enum.map(args_keyword_list, fn {dependency, _binding} -> {dependency, fn_name} end)
    end)
  end
end
