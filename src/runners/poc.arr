include file("../utils.arr")
import file("../core.arr") as C
import file("../grading.arr") as G
# TODO: proper implementation
import file("../../poc/runners.arr") as R
import lists as L

provide:
  self-test,
  functional,
  chaff,
  wheat,
end

# TODO:
# - error handling
# - better feedback
# - performance
fun tmp-run-with-alternate-impl(
  student-path :: String, alt-impl-path :: String, fun-name :: String
) -> { Number; Number; String }:
  tests = R.run-with-alternate-impl(student-path, alt-impl-path, fun-name)
  passed = tests.get("passed").n().v
  total = tests.get("total").n().v
  results = tests
    .get("results").v
    .and-then(lam(x): x.native().map(_.get-value("message")).join-str("\n") end)
    .or-else("") # TODO: much nicer error messages when rewritten
  # spy "tmp-run-with-alternate-impl": passed, total, results end
  { passed; total; results }
end

fun tmp-run-extra-check(
  student-path :: String, check-path :: String, check-name :: String
) -> { Number; Number; String }:
  tests = R.run-extra-check(student-path, check-path, check-name)
  passed = tests.get("passed").n().v
  total = tests.get("total").n().v
  results = tests
    .get("results").v
    .and-then(lam(x): x.native().map(_.get-value("message")).join-str("\n") end)
    .or-else("") # TODO: much nicer error messages when rewritten
  # spy "tmp-run-extra-check": tests, tests-serial: tests.v.and-then(_.serialize()), passed, total, results end
  { passed; total; results }
end

fun self-test(
  student-path :: String, fun-name :: String
) -> (-> G.GradingOutcome):
  lam():
    { passed; total; results } = tmp-run-with-alternate-impl(student-path, student-path, fun-name)
    score = if total == 0: 0 else: passed / total end
    C.done(G.score(score), G.grade-info(results))
  end
end

fun functional(
  student-path :: String, reference-path :: String, check-name :: String
) -> (-> G.GradingOutcome):
  lam():
    { passed; total; results } = tmp-run-extra-check(student-path, reference-path, check-name)
    score = if total == 0: 0 else: passed / total end
    C.done(G.score(score), G.grade-info(results))
  end
end

fun chaff(
  student-path :: String, chaff-path :: String, function-name:: String
) -> (-> G.GradingOutcome):
  lam():
    { passed; total; results } = tmp-run-with-alternate-impl(student-path, chaff-path, function-name)
    score = if passed <> total: 1 else: 0 end
    C.done(G.score(score), G.grade-info(results))
  end
end

fun wheat(
  student-path :: String, wheat-path :: String, function-name :: String
) -> (-> G.GradingOutcome):
  lam():
    { passed; total; results } = tmp-run-with-alternate-impl(student-path, wheat-path, function-name)
    score = if passed == total: 1 else: 0 end
    C.done(G.score(score), G.grade-info(results))
  end
end

