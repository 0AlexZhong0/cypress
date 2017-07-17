_ = require("lodash")
Backbone = require("backbone")
moment = require("moment")
Promise = require("bluebird")

$Log = require("./log")
$utils = require("./utils")

id = 0

defaultGrepRe   = /.*/
mochaCtxKeysRe  = /^(_runnable|test)$/
betweenQuotesRe = /\"(.+?)\"/

ERROR_PROPS      = "message type name stack fileName lineNumber columnNumber host uncaught actual expected showDiff".split(" ")
RUNNABLE_LOGS    = "routes agents commands".split(" ")
RUNNABLE_PROPS   = "id title root hookName err duration state failedFromHook body".split(" ")

# ## initial payload
# {
#   suites: [
#     {id: "r1"}, {id: "r4", suiteId: "r1"}
#   ]
#   tests: [
#     {id: "r2", title: "foo", suiteId: "r1"}
#   ]
# }

# ## normalized
# {
#   {
#     root: true
#     suites: []
#     tests: []
#   }
# }

# ## resetting state (get back from server)
# {
#   scrollTop: 100
#   tests: {
#     r2: {id: "r2", title: "foo", suiteId: "r1", state: "passed", err: "", routes: [
#         {}, {}
#       ]
#       agents: [
#       ]
#       commands: [
#         {}, {}, {}
#       ]
#     }}
#
#     r3: {id: "r3", title: "bar", suiteId: "r1", state: "failed", logs: {
#       routes: [
#         {}, {}
#       ]
#       spies: [
#       ]
#       commands: [
#         {}, {}, {}
#       ]
#     }}
#   ]
# }

waitForHooksToResolve = (ee, event, test = {}) ->
  ## get an array of event listeners
  # events = fire.call(ctx, event, test, {multiple: true})
  #
  # events = _.filter events, (r) ->
  #   ## get us out only promises
  #   ## due to a bug in bluebird with
  #   ## not being able to call {}.hasOwnProperty
  #   ## https://github.com/petkaantonov/bluebird/issues/1104
  #   ## TODO: think about applying this to the other areas
  #   ## that use Cypress.invoke(...)
  #   $utils.isInstanceOf(r, Promise)

  # Promise.all(events)
  ee.emitThen(event, test)
  .catch (err) ->
    ## this doesn't take into account events running prior to the
    ## test - but this is the best we can do considering we don't
    ## yet have test.callback (from mocha). so we just override
    ## its fn to automatically throw. however this really shouldn't
    ## ever even happen since the webapp prevents you from running
    ## tests to begin with. but its here just in case.
    test.fn = ->
      throw err

fire = (event, test, Cypress, options = {}) ->
  test._fired ?= {}
  test._fired[event] = true

  ## dont fire anything again if we are skipped
  return if test._ALREADY_RAN

  Cypress.action(event, wrap(test))

fired = (event, test) ->
  !!(test._fired and test._fired[event])

testBeforeRun = (test, Cypress) ->
  Promise.try ->
    if not fired("runner:test:before:run:async", test)
      fire("runner:test:before:run:async", test, Cypress)

reduceProps = (obj, props) ->
  _.reduce props, (memo, prop) ->
    if _.has(obj, prop) or obj[prop]
      memo[prop] = obj[prop]
    memo
  , {}

wrap = (runnable) ->
  ## we need to optimize wrap by converting
  ## tests to an id-based object which prevents
  ## us from recursively iterating through every
  ## parent since we could just return the found test
  reduceProps(runnable, RUNNABLE_PROPS)

wrapAll = (runnable) ->
  _.extend(
    {},
    reduceProps(runnable, RUNNABLE_PROPS),
    reduceProps(runnable, RUNNABLE_LOGS)
  )

wrapErr = (err) ->
  reduceProps(err, ERROR_PROPS)

getHookName = (hook) ->
  ## find the name of the hook by parsing its
  ## title and pulling out whats between the quotes
  name = hook.title.match(betweenQuotesRe)
  name and name[1]

anyTestInSuite = (suite, fn) ->
  for test in suite.tests
    return true if fn(test) is true

  for suite in suite.suites
    return true if anyTestInSuite(suite, fn) is true

  ## else return false
  return false

onFirstTest = (suite, fn) ->
  for test in suite.tests
    return test if fn(test)

  for suite in suite.suites
    return test if test = onFirstTest(suite, fn)

getAllSiblingTests = (suite, getTestById) ->
  tests = []
  suite.eachTest (test) =>
    ## iterate through each of our suites tests.
    ## this will iterate through all nested tests
    ## as well.  and then we add it only if its
    ## in our grepp'd _this.tests array
    if getTestById(test.id)
      tests.push test

  tests

getTestFromHook = (hook, suite, getTestById) ->
  ## if theres already a currentTest use that
  return test if test = hook?.ctx.currentTest

  ## if we have a hook id then attempt
  ## to find the test by its id
  if hook?.id
    found = onFirstTest suite, (test) =>
      hook.id is test.id

    return found if found

  ## returns us the very first test
  ## which is in our grepped tests array
  ## based on walking down the current suite
  ## iterating through each test until it matches
  found = onFirstTest suite, (test) =>
    getTestById(test.id)

  return found if found

  ## have one last final fallback where
  ## we just return true on the very first
  ## test (used in testing)
  onFirstTest suite, (test) -> true

overrideRunnerHook = (ee, runner, getTestById, getTest, setTest, getTests) ->
  ## bail if our runner doesnt have a hook.
  ## useful in tests
  return if not runner.hook

  ## monkey patch the hook event so we can wrap
  ## 'test:before:run:async' and 'test:after:hooks' around all of
  ## the hooks surrounding a test runnable
  _this = @

  runner.hook = _.wrap runner.hook, (orig, name, fn) ->
    hooks = @suite["_" + name]

    ## we have to see if this is the last suite amongst
    ## its siblings.  but first we have to filter out
    ## suites which dont have a grep'd test in them
    isLastSuite = (suite) ->
      return false if suite.root

      ## grab all of the suites from our grep'd tests
      ## including all of their ancestor suites!
      suites = _.reduce _this.tests, (memo, test) ->
        while parent = test.parent
          memo.push(parent)
          test = parent
        memo
      , []

      ## intersect them with our parent suites and see if the last one is us
      _
      .chain(suites)
      .uniq()
      .intersection(suite.parent.suites)
      .last()
      .value() is suite


    testAfterHooks = ->
      test = getTest()

      setTest(null)

      fn = _.wrap fn, (orig, args...) ->
        testEvents.afterHooksAsync(ee, test)
        .then ->
          testEvents.afterRun(ee, test)

          Cypress.restore()

          orig(args...)



      when "afterEach"
        ## find all of the grep'd _this tests which share
        ## the same parent suite as our current _this test
        tests = getAllSiblingTests(getTest().parent, getTestById)

        ## make sure this test isnt the last test overall but also
        ## isnt the last test in our grep'd parent suite's tests array
        if @suite.root and (getTest() isnt _.last(getTests())) and (getTest() isnt _.last(tests))
          testAfterHooks()

      when "afterAll"
        ## find all of the grep'd _this tests which share
        ## the same parent suite as our current _this test
        if getTest()
          tests = getAllSiblingTests(getTest().parent, getTestById)

          ## if we're the very last test in the entire _this.tests
          ## we wait until the root suite fires
          ## else we wait until the very last possible moment by waiting
          ## until the root suite is the parent of the current suite
          ## since that will bubble up IF we're the last nested suite
          ## else if we arent the last nested suite we fire if we're
          ## the last test
          if (@suite.root and getTest() is _.last(getTests())) or
            (@suite.parent?.root and getTest() is _.last(tests)) or
              (not isLastSuite(@suite) and getTest() is _.last(tests))
            testAfterHooks()

    orig.call(@, name, fn)

getId = ->
  ## increment the id counter
  "r" + (id += 1)

matchesGrep = (runnable, grep) ->
  ## we have optimized this iteration to the maximum.
  ## we memoize the existential matchesGrep property
  ## so we dont regex again needlessly when going
  ## through tests which have already been set earlier
  if (not runnable.matchesGrep?) or (not _.isEqual(runnable.grepRe, grep))
    runnable.grepRe      = grep
    runnable.matchesGrep = grep.test(runnable.fullTitle())

  runnable.matchesGrep

getTestResults = (tests) ->
  _.map tests, (test) ->
    obj = _.pick(test, "id", "duration", "state")
    obj.title = test.originalTitle
    ## TODO FIX THIS!
    if not obj.state
      obj.state = "skipped"
    obj

normalizeAll = (suite, initialTests = {}, grep, setTestsById, setTests, onRunnable, onLogsById) ->
  hasTests = false

  ## only loop until we find the first test
  onFirstTest suite, (test) ->
    hasTests = true

  ## if we dont have any tests then bail
  return if not hasTests

  ## we are doing a super perf loop here where
  ## we hand back a normalized object but also
  ## create optimized lookups for the tests without
  ## traversing through it multiple times
  tests         = {}
  grepIsDefault = _.isEqual(grep, defaultGrepRe)

  obj = normalize(suite, tests, initialTests, grep, grepIsDefault, onRunnable, onLogsById)

  if setTestsById
    ## use callback here to hand back
    ## the optimized tests
    setTestsById(tests)

  if setTests
    ## same pattern here
    setTests(_.values(tests))

  return obj

normalize = (runnable, tests, initialTests, grep, grepIsDefault, onRunnable, onLogsById) ->
  normalizer = (runnable) =>
    runnable.id = getId()

    ## tests have a type of 'test' whereas suites do not have a type property
    runnable.type ?= "suite"

    if onRunnable
      onRunnable(runnable)

    ## if we have a runnable in the initial state
    ## then merge in existing properties into the runnable
    if i = initialTests[runnable.id]
      _.each RUNNABLE_LOGS, (type) =>
        _.each i[type], onLogsById

      _.extend(runnable, i)

    ## reduce this runnable down to its props
    ## and collections
    return wrapAll(runnable)

  push = (test) =>
    tests[test.id] ?= test

  obj = normalizer(runnable)

  ## if we have a default grep then avoid
  ## grepping altogether and just push
  ## tests into the array of tests
  if grepIsDefault
    if runnable.type is "test"
      push(runnable)

    ## and recursively iterate and normalize all other runnables
    _.each {tests: runnable.tests, suites: runnable.suites}, (runnables, key) =>
      if runnable[key]
        obj[key] = _.map runnables, (runnable) =>
          normalize(runnable, tests, initialTests, grep, grepIsDefault, onRunnable, onLogsById)
  else
    ## iterate through all tests and only push them in
    ## if they match the current grep
    obj.tests = _.reduce runnable.tests ? [], (memo, test) =>
      ## only push in the test if it matches
      ## our grep
      if matchesGrep(test, grep)
        memo.push(normalizer(test))
        push(test)
      memo
    , []

    ## and go through the suites
    obj.suites = _.reduce runnable.suites ? [], (memo, suite) =>
      ## but only add them if a single nested test
      ## actually matches the grep
      any = anyTestInSuite suite, (test) =>
        matchesGrep(test, grep)

      if any
        memo.push(
          normalize(
            suite,
            tests,
            initialTests,
            grep,
            grepIsDefault,
            onRunnable
          )
        )

      memo
    , []

  return obj

afterEachFailed = (Cypress, test, err) ->
  test.state = "failed"
  test.err = wrapErr(err)

  Cypress.action("runner:test:end", wrap(test))

hookFailed = (hook, err, hookName, getTestById) ->
  ## finds the test by returning the first test from
  ## the parent or looping through the suites until
  ## it finds the first test
  test = getTestFromHook(hook, hook.parent, getTestById)
  test.err = err
  test.state = "failed"
  test.duration = hook.duration
  test.hookName = hookName
  test.failedFromHook = true

  if hook.alreadyEmittedMocha
    ## TODO: won't this always hit right here???
    ## when would the hook not be emitted at this point?
    test.alreadyEmittedMocha = true
  else
    Cypress.action("runner:test:end", wrap(test))

runnerListeners = (runner, Cypress, emissions, getTestById, setTest) ->
  runner.on "start", ->
    Cypress.action("runner:start")

  runner.on "end", ->
    Cypress.action("runner:end")

  runner.on "suite", (suite) ->
    return if emissions.started[suite.id]

    emissions.started[suite.id] = true

    Cypress.action("runner:suite:start", wrap(suite))

  runner.on "suite end", (suite) ->
    ## perf loop
    for key, value of suite.ctx
      delete suite.ctx[key]

    return if emissions.ended[suite.id]

    emissions.ended[suite.id] = true

    Cypress.action("runner:suite:end", wrap(suite))

  runner.on "hook", (hook) ->
    hookName = getHookName(hook)

    ## mocha incorrectly sets currentTest on before all's.
    ## if there is a nested suite with a before, then
    ## currentTest will refer to the previous test run
    ## and not our current
    if hookName is "before all" and hook.ctx.currentTest
      delete hook.ctx.currentTest

    ## set the hook's id from the test because
    ## hooks do not have their own id, their
    ## commands need to grouped with the test
    ## and we can only associate them by this id
    test = getTestFromHook(hook, hook.parent, getTestById)
    hook.id = test.id
    hook.ctx.currentTest = test

    Cypress.action("runner:hook:start", wrap(hook))

  runner.on "hook end", (hook) ->
    hookName = getHookName(hook)

    Cypress.action("runner:hook:end", wrap(hook))

  runner.on "test", (test) ->
    setTest(test)

    return if emissions.started[test.id]

    emissions.started[test.id] = true

    Cypress.action("runner:test:start", wrap(test))

  runner.on "test end", (test) ->
    return if emissions.ended[test.id]

    emissions.ended[test.id] = true

    Cypress.action("runner:test:end", wrap(test))

  runner.on "pass", (test) ->
    Cypress.action("runner:pass", wrap(test))

  ## if a test is pending mocha will only
  ## emit the pending event instead of the test
  ## so we normalize the pending / test events
  runner.on "pending", (test) ->
    ## do nothing if our test is skipped
    return if test._ALREADY_RAN

    if not fired("test:before:run:async", test)
      fire("test:before:run:async", test, Cypress)

    test.state = "pending"

    if not test.alreadyEmittedMocha
      ## do not double emit this event
      test.alreadyEmittedMocha = true

      Cypress.action("runner:pending", wrap(test))

    @emit("test", test)

    ## if this is not the last test amongst its siblings
    ## then go ahead and fire its test:after:run event
    ## else this will not get called
    tests = getAllSiblingTests(test.parent, getTestById)

    if _.last(tests) isnt test
      fire(Cypress, "test:after:run", test)

  runner.on "fail", (runnable, err) ->
    isHook = runnable.type is "hook"

    if isHook
      parentTitle = runnable.parent.title
      hookName    = getHookName(runnable)

      ## append a friendly message to the error indicating
      ## we're skipping the remaining tests in this suite
      err.message += "\n\n" + $utils.errMessageByPath("uncaught.error_in_hook", {parentTitle, hookName})

    ## always set runnable err so we can tap into
    ## taking a screenshot on error
    runnable.err = wrapErr(err)

    if not runnable.alreadyEmittedMocha
      ## do not double emit this event
      runnable.alreadyEmittedMocha = true

      Cypress.action("runner:fail", wrap(runnable), runnable.err)

    if isHook
      ## TODO: why do we need to do this???
      hookFailed(runnable, runnable.err, hookName, getTestById)

create = (mocha, Cypress) ->
  id = 0

  runner = mocha.getRunner()
  runner.suite = mocha.getRootSuite()

  ## this is used in tests since we provide
  ## the tests immediately
  # normalizeAll(runner.suite, {}, grep()) if runner.suite

  ## hold onto the runnables for faster lookup later
  test = null
  tests = []
  testsById = {}
  testsQueue = []
  testsQueueById = {}
  runnables = []
  logsById = {}
  emissions = {
    started: {}
    ended:   {}
  }
  startTime = null

  # @listeners()

  setTestsById = (tbid) ->
    testsById = tbid

  setTests = (t) ->
    tests = t

  onRunnable = (r) ->
    runnables.push(r)

  onLogsById = (l) ->
    logsById[l.id] = l

  getTest = ->
    test

  setTest = (t) ->
    test = t

  getTests = ->
    tests

  getTestById = (id) ->
    ## perf short circuit
    return if not id

    testsById[id]

  overrideRunnerHook(Cypress, runner, getTestById, getTest, setTest, getTests)

  return {
    id

    grep: (re) ->
      if arguments.length
        runner._grep = re
      else
        ## grab grep from the mocha runner
        ## or just set it to all in case
        ## there is a mocha regression
        runner._grep ?= defaultGrepRe

    options: (options = {}) ->
      ## TODO
      ## need to handle
      ## ignoreLeaks, asyncOnly, globals

      if re = options.grep
        @grep(re)

    fail: (err, runnable) ->
      ## if runnable.state is passed then we've
      ## probably failed in an afterEach and need
      ## to update the runnable to failed status
      if runnable.state is "passed"
        afterEachFailed(Cypress, runnable, err)

      runnable.callback(err)

    normalizeAll: (tests) ->
      normalizeAll(
        runner.suite,
        tests,
        @grep(),
        setTestsById,
        setTests,
        onRunnable,
        onLogsById
      )

    run: (fn) ->
      startTime ?= moment().toJSON()

      runnerListeners(runner, Cypress, emissions, getTestById, setTest)

      runner.run (failures) =>
        ## TODO this functions is not correctly
        ## synchronized with the 'end' event that
        ## we manage because of uncaught hook errors
        fn(failures, getTestResults(tests)) if fn

    onRunnableRun: (runnableRun, runnable, args) ->
      if not runnable.id
        debugger
        throw new Error("runnable must have an id", runnable.id)

      ## if this isnt a hook, then the name is 'test'
      hookName = getHookName(runnable) or "test"

      switch runnable.type
        when "hook"
          test = runnable.ctx.currentTest
        when "test"
          test = runnable

      ## TODO: handle promise timeouts here!
      ## whenever any runnable is about to run
      ## we figure out what test its associated to
      ## if its a hook, and then we fire the
      ## test:before:run:async action if its not
      ## been fired before for this test
      testBeforeRun(test, Cypress)
      .then ->
        ## and regardless we can now tell cy
        ## that its ready to set the runnable
        Cypress.action("runner:set:runnable", runnable, hookName)
      .catch (err) ->
        ## TODO: if our async tasks fail
        ## then allow us to cause the test
        ## to fail here by blowing up its fn
        ## callback
        fn = runnable.fn

        restore = ->
          runnable.fn = fn

        runnable.fn = ->
          restore()

          throw err
      .finally ->
        runnableRun.apply(runnable, args)

    getStartTime: ->
      startTime

    setStartTime: (iso) ->
      startTime = iso

    getErrorByTestId: (testId) ->
      if test = getTestById(testId)
        wrapErr(test.err)

    getDisplayPropsForLog: $Log.getDisplayProps

    getConsolePropsForLogById: (logId) ->
      if attrs = logsById[logId]
        $Log.getConsoleProps(attrs)

    getSnapshotPropsForLogById: (logId) ->
      if attrs = logsById[logId]
        $Log.getSnapshotProps(attrs)

    getErrorByTestId: (testId) ->
      if test = getTestById(testId)
        wrapErr(test.err)

    cleanupQueue: (numTestsKeptInMemory) ->
      cleanup = (queue) ->
        if queue.length > numTestsKeptInMemory
          test = queue.shift()

          delete testsQueueById[test.id]

          _.each RUNNABLE_LOGS, (logs) ->
            _.each test[logs], (attrs) ->
              ## we know our attrs have been cleaned
              ## now, so lets store that
              attrs._hasBeenCleanedUp = true

              $Log.reduceMemory(attrs)

          cleanup(queue)

      cleanup(testsQueue)

    addLog: (attrs, isHeadless) ->
      ## we dont need to hold a log reference
      ## to anything in memory when we're headless
      ## because you cannot inspect any logs
      return if isHeadless

      test = getTestById(attrs.testId)

      ## bail if for whatever reason we
      ## cannot associate this log to a test
      return if not test

      ## if this test isnt in the current queue
      ## then go ahead and add it
      if not testsQueueById[test.id]
        testsQueueById[test.id] = true
        testsQueue.push(test)

      if existing = logsById[attrs.id]
        ## because log:state:changed may
        ## fire at a later time, its possible
        ## we've already cleaned up these attrs
        ## and in that case we don't want to do
        ## anything at all
        return if existing._hasBeenCleanedUp

        ## mutate the existing object
        _.extend(existing, attrs)
      else
        logsById[attrs.id] = attrs

        { testId, instrument } = attrs

        if test = getTestById(testId)
          ## pluralize the instrument
          ## as a property on the runnable
          logs = test[instrument + "s"] ?= []

          ## else push it onto the logs
          logs.push(attrs)
  }

module.exports = {
  overrideRunnerHook

  normalize

  normalizeAll

  create
}
