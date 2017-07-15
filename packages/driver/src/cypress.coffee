_ = require('lodash')
$ = require("jquery")
Backbone = require("backbone")
blobUtil = require("blob-util")
minimatch = require("minimatch")
moment = require("moment")
Promise = require("bluebird")
sinon = require("sinon")
lolex = require("lolex")
Cookies = require("js-cookie")
bililiteRange = require("../vendor/bililiteRange")

$Chainer = require("./cypress/chainer")
$Command = require("./cypress/command")
$Commands = require("./cypress/commands")
$Cookies = require("./cypress/cookies")
$Cy = require("./cypress/cy")
$Dom = require("./cypress/dom")
$Events = require("./cypress/events")
$SetterGetter = require("./cypress/setter_getter")
$ErrorMessages = require("./cypress/error_messages")
$Keyboard = require("./cypress/keyboard")
$Log = require("./cypress/log")
$Location = require("./cypress/location")
$LocalStorage = require("./cypress/local_storage")
$Mocha = require("./cypress/mocha")
$Runner = require("./cypress/runner")
$Server = require("./cypress/server")

$utils = require("./cypress/utils")

proxies = {
  runner: "getStartTime getTestsState getEmissions countByTestState getDisplayPropsForLog getConsolePropsForLogById getSnapshotPropsForLogById getErrorByTestId normalizeAll".split(" ")
  cy: "checkForEndedEarly onUncaughtException setRunnable getStyles".split(" ")
}

throwDeprecatedCommandInterface = (key, method) ->
  signature = switch method
    when "addParentCommand"
      "'#{key}', function(){...}"
    when "addChildCommand"
      "'#{key}', { prevSubject: true }, function(){...}"
    when "addDualCommand"
      "'#{key}', { prevSubject: 'optional' }, function(){...}"

  $utils.throwErrByPath("miscellaneous.custom_command_interface_changed", {
    args: { method, signature }
  })

throwPrivateCommandInterface = (method) ->
  $utils.throwErrByPath("miscellaneous.private_custom_command_interface", {
    args: { method }
  })

class $Cypress
  constructor: (config = {}) ->
    @cy       = null
    @chai     = null
    @mocha    = null
    @runner   = null
    @Commands = null
    @_RESUMED_AT_TEST = null

    @events = $Events.extend(@)

    @setConfig(config)

  setConfig: (config = {}) ->
    ## config.remote
    # {
    #   origin: "http://localhost:2020"
    #   domainName: "localhost"
    #   props: null
    #   strategy: "file"
    # }

    # -- or --

    # {
    #   origin: "https://foo.google.com"
    #   domainName: "google.com"
    #   strategy: "http"
    #   props: {
    #     port: 443
    #     tld: "com"
    #     domain: "google"
    #   }
    # }

    ## set domainName but allow us to turn
    ## off this feature in testing
    if d = config.remote?.domainName
      document.domain = d

    @version = config.version
    @isHeadless = !!config.isHeadless

    {environmentVariables, remote} = config

    config = _.omit(config, "environmentVariables", "remote")

    @state = $SetterGetter.create({})
    @config = $SetterGetter.create(config)
    @env = $SetterGetter.create(environmentVariables)

    @Cookies = $Cookies.create(config.namespace, d)

    @emit("config", config)

  initialize: ($autIframe) ->
    ## push down the options
    ## to the runner
    @mocha.options(@runner)

    @cy.initialize($autIframe)

  run: (fn) ->
    $utils.throwErrByPath("miscellaneous.no_runner") if not @runner

    @Commands.each (cmd) =>
      @cy.addCommand(cmd)

    @runner.run(fn)

  ## onSpecWindow is called as the spec window
  ## is being served but BEFORE any of the actual
  ## specs or support files have been downloaded
  ## or parsed. we have not received any custom commands
  ## at this point
  onSpecWindow: (specWindow) ->
    logFn = =>
      @log.apply(@, arguments)

    ## create cy and expose globally
    @cy = window.cy = $Cy.create(specWindow, @, @state, @config, logFn)
    @log = $Log.create(@, @cy, @state, @config)
    @mocha = $Mocha.create(specWindow, @)
    @runner = $Runner.create(@mocha, @)

    ## wire up command create to cy
    @Commands = $Commands.create(@, @cy, @state, @config, @log)

    return null

  action: (eventName, args...) ->
    ## normalizes all the various ways
    ## other objects communicate intent
    ## and 'action' to Cypress
    switch eventName
      when "runner:start"
        ## mocha runner has begun running the tests
        @emit("run:start")

        return if @_RESUMED_AT_TEST

        if @isHeadless
          @emit("mocha", "start")

      when "runner:end"
        ## mocha runner has finished running the tests

        ## end may have been caused by an uncaught error
        ## that happened inside of a hook.
        ##
        ## when this happens mocha aborts the entire run
        ## and does not do the usual cleanup so that means
        ## we have to fire the test:after:hooks and
        ## test:after:run events ourselves
        @emit("run:end")

        if @isHeadless
          @emit("mocha", "end")

        @restore()

        ## TODO: we may not need to do any of this
        ## it appears only afterHooksAsync is needed
        ## for taking a screenshot - which can likely
        ## be done better (and likely doesnt need to wait
        ## until after the hooks have run anyway!)
        ##
        ## the test:after:run event is only used for
        ## cleaning up num tests kept in memory


        ## if we have a test and err
        # test = _this.test
        # err  = test and test.err
        #
        # ## and this err is uncaught
        # if err and err.uncaught
        #
        #   ## fire all the events
        #   testEvents.afterHooksAsync(_this, test)
        #   .then ->
        #     testEvents.afterRun(_this, test)
        #
        #     end()
        # else
        #   end()

      when "runner:set:runnable"
        ## when there is a hook / test (runnable) that
        ## is about to be invoked
        @setRunnable(args...)

      when "runner:suite:start"
        ## mocha runner started processing a suite
        if @isHeadless
          @emit("mocha", "suite", args...)

      when "runner:suite:end"
        ## mocha runner finished processing a suite
        if @isHeadless
          @emit("mocha", "suite end", args...)

      when "runner:hook:start"
        ## mocha runner started processing a hook
        if @isHeadless
          @emit("mocha", "hook", args...)

      when "runner:hook:end"
        ## mocha runner finished processing a hook
        if @isHeadless
          @emit("mocha", "hook end", args...)

      when "runner:test:start"
        ## mocha runner started processing a hook
        if @isHeadless
          @emit("mocha", "test", args...)

      when "runner:test:end"
        ## mocha runner finished processing a hook
        @checkForEndedEarly()

        if @isHeadless
          @emit("mocha", "test end", args...)

      when "runner:pass"
        ## mocha runner calculated a pass
        if @isHeadless
          @emit("mocha", "pass", args...)

      when "runner:pending"
        ## mocha runner calculated a pending test
        if @isHeadless
          @emit("mocha", "pending", args...)

      when "runner:fail"
        ## mocha runner calculated a failure
        if @isHeadless
          @emit("mocha", "fail", args...)

      when "cy:fail"
        @runner.fail(args...)

        ## comes from cypress errors fail()
        @emit("fail", args...)

        ## also emits this on cy
        ## @cy.emit("fail", args...)

      when "test:after:run"
        @runner.cleanupQueue(@config("numTestsKeptInMemory"))

        @emit("test:after:run", args...)

      when "command:enqueue"
        "asdf"

      when "command:log:added"
        @runner.addLog(args[0], @isHeadless)

        @emit("log:added", args...)

      when "command:log:changed"
        "asdf"
        @runner.addLog(args[0], @isHeadless)

        @emit("log:changed", args...)

      when "cy:command:enqueued"
        @emit("command:enqueued", args[0])

      when "aut:before:window:load"
        @cy.onBeforeAutWindowLoad(args[0])

        @emit("aut:before:window:load", args[0])

  request: (eventName, args...) ->
    new Promise (resolve, reject) =>
      fn = (reply) ->
        ## TODO: normalize this to reply.error and reply.response
        if e = reply.error
          err = $utils.cypressErr(e.message)
          err.name = e.name
          err.stack = e.stack

          reject(err)
        else
          resolve(reply.response)

      @emit("backend:request", eventName, args..., fn)

  automation: (eventName, args...) ->
    ## wrap action in promise
    new Promise (resolve, reject) =>
      fn = (reply) ->
        ## TODO: normalize this to reply.error and reply.response
        if e = reply.__error
          err = $utils.cypressErr(e)
          err.name = reply.__name
          err.stack = reply.__stack

          reject(err)
        else
          resolve(reply.response)

      @emit("automation:request", eventName, args..., fn)

  abort: ->
    @emitThen("abort")
    .then =>
      @restore()

  ## restores cypress after each test run by
  ## removing the queue from the proto and
  ## removing additional own instance properties
  restore: ->
    @emitThen("restore")
    .return(null)

  addChildCommand: (key, fn) ->
    throwDeprecatedCommandInterface(key, "addChildCommand")

  addParentCommand: (key, fn) ->
    throwDeprecatedCommandInterface(key, "addParentCommand")

  addDualCommand: (key, fn) ->
    throwDeprecatedCommandInterface(key, "addDualCommand")

  addAssertionCommand: (key, fn) ->
    throwPrivateCommandInterface("addAssertionCommand")

  addUtilityCommand: (key, fn) ->
    throwPrivateCommandInterface("addUtilityCommand")

  $: ->
    if not @cy
      $utils.throwErrByPath("miscellaneous.no_cy")

    @cy.$$.apply(@cy, arguments)

  ## attach to $Cypress to access
  ## all of the constructors
  ## to enable users to monkeypatch
  $Cypress: $Cypress

  Location: $Location

  Log: $Log

  utils: $utils

  _: _

  moment: moment

  Blob: blobUtil

  Promise: Promise

  minimatch: minimatch

  sinon: sinon

  lolex: lolex

  bililiteRange: bililiteRange

  _.extend $Cypress.prototype.$, _.pick($, "Event", "Deferred", "ajax", "get", "getJSON", "getScript", "post", "when")

  @create = (config) ->
    new $Cypress(config)

  @extend = (obj) ->
    _.extend @prototype, obj

  ## proxy all of the methods in proxies
  ## to their corresponding objects
  _.each proxies, (methods, key) ->
    _.each methods, (method) ->
      $Cypress.prototype[method] = ->
        prop = @[key]

        prop and prop[method].apply(prop, arguments)

## attach these to the prototype
## instead of $Cypress
$Cypress.$ = $
$Cypress.Chai = $Chai
$Cypress.Chainer = $Chainer
$Cypress.Command = $Command
$Cypress.Commands = $Commands
$Cypress.Cookies = $Cookies
$Cypress.Cy = $Cy
$Cypress.Dom = $Cypress.prototype.Dom = $Dom
$Cypress.Events = $Events
$Cypress.ErrorMessages = $ErrorMessages
$Cypress.Keyboard = $Keyboard
$Cypress.Log = $Log
$Cypress.Location = $Location
$Cypress.LocalStorage = $LocalStorage
$Cypress.Mocha = $Mocha
$Cypress.Runner = $Runner
$Cypress.Server = $Cypress.prototype.Server = $Server
$Cypress.utils = $utils

## expose globally (temporarily for the runner)
window.$Cypress = $Cypress

module.exports = $Cypress



## QUESTION:
## Do we need to expose $Cypress?
## how do we attach submodules / other utilities?
## move things around / reorganize how its attached
