import lists as L
import sets as S
import string-dict as SD

include file("./utils.arr")

provide:
  data Node,
  data Outcome,

  type DAG,
  type Id,
  type Runner,
  type Outcome,

  execute,
  valid-dag as _valid-dag,
  topological-sort as _topological-sort
end

type Id = String

type Runner<BlockReason, RanResult, Error> =
  (-> Outcome<BlockReason, RanResult, Error>)

data Node<BlockReason, RanResult, Error, Metadata>:
  # id: unique id of the node
  # deps: the dependencies of this node
  # run: the action that will be executed if dependencies are met
  | node(
      id :: Id,
      deps :: List<Id>,
      run :: Runner<BlockReason, RanResult, Error>,
      metadata :: Metadata)
end

data Outcome<BlockReason, RanResult, Error>:
  # reason: the reason for the block
  | block(reason :: BlockReason)
  # node has no effect
  | proceed

  | done(res :: RanResult)
  # path: the path of the artifacts
  | artifact(path :: String)

  # id: the id of the node which `block`ed this node
  | skipped(id :: Id)

  | internal-error(err :: Error)
sharing:
  # id: id of the node which produced this outcome
  method handle-skip(self, id :: Id) -> Option<Id>:
    cases (Outcome) self:
      | block(_) => some(id)
      | proceed => none
      | done(_) => none
      | artifact(_) => none
      | skipped(shadow id) => some(id)
      | internal-error(_) => some(id)
    end
  end
end

fun valid-dag<BlockReason, RanResult, Error, Metadata>(
  dag :: List<Node<BlockReason, RanResult, Error, Metadata>>
) -> Boolean block:
  ids = dag.map(_.id)
  no-dups = lam(): not(has-duplicates(ids)) end
  all-deps-exist = lam(): dag.all(lam(x): x.deps.all(ids.member(_)) end) end

  dict = list-to-stringdict(dag.map(lam(n): {n.id; n.deps} end))

  fun has-cycle-from(id :: Id, path-set :: S.Set<Id>):
    dict.get-value(id).any(lam(dep):
      path-set.member(dep) or
      has-cycle-from(dep, path-set.add(dep))
    end)
  end

  no-cycles = lam(): not(ids.any(lam(id): has-cycle-from(id, [S.list-set: id]) end)) end

  no-dups() and all-deps-exist() and no-cycles()
end

type DAG<BlockReason, RanResult, Error, Metadata> =
  List<Node<BlockReason, RanResult, Error, Metadata>>%(valid-dag)

fun topological-sort<BlockReason, RanResult, Error, Metadata>(
  dag :: DAG<BlockReason, RanResult, Error, Metadata>
) -> DAG<BlockReason, RanResult, Error, Metadata>:
  doc: ```Return a new list whose order guarantees that every node appears only
          after all of its dependencies.```

  fun help(
    remaining :: List<Node<BlockReason, RanResult, Error, Metadata>>,
    sorted :: List<Node<BlockReason, RanResult, Error, Metadata>>,
    visited :: List<Id>
  ) -> List<Node<BlockReason, RanResult, Error, Metadata>>:
    cases (List<Node<BlockReason, RanResult, Error, Metadata>>) remaining:
      | empty => sorted
      | else =>
        ready = remaining.filter(lam(n): n.deps.all(visited.member(_)) end)
        rest = remaining.filter(lam(n): not(n.deps.all(visited.member(_))) end)
        help(rest, sorted + ready, visited + ready.map(_.id))
    end
  end

  help(dag, [list:], [list:])
end

fun should-skip<B, R, E>(results :: SD.StringDict<Outcome<B, R, E>>, deps :: List<Id>) -> Option<Id>:
  cases (List) deps:
    | empty => none
    | link(id, rst) =>
      cases (Option) results.get-value(id).handle-skip(id):
        | none => should-skip(results, rst)
        | some(responsible-id) => some(responsible-id)
      end
  end
end

fun execute<B, R, E, M>(dag :: DAG<B, R, E, M>) -> SD.StringDict<Outcome<B, R, E>>:
  doc: "executes the dag, propogating outcomes"

  fun help(shadow dag :: List<Node<B, R, E, M>>, acc :: SD.StringDict<Outcome<B, R, E>>) -> SD.StringDict<Outcome<B, R, E>>:
    cases (List<Node<B, R, E, M>>) dag:
      | empty => acc
      | link(shadow node, rst) =>
        help(rst,
          cases (Option) should-skip(acc, node.deps):
            | none => acc.set(node.id, node.run())
            | some(blocking-id) => acc.set(node.id, skipped(blocking-id))
          end)
    end
  end

  help(topological-sort(dag), [SD.string-dict:])
end

