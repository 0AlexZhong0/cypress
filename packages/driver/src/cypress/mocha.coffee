_ = require("lodash")
Backbone = require("backbone")
utils = require("./utils")

mocha = require("mocha")

Mocha = mocha.Mocha ? mocha
Runner = Mocha.Runner
Runnable = Mocha.Runnable

runnerRun            = Runner::run
runnerFail           = Runner::fail
runnableRun          = Runnable::run
runnableResetTimeout = Runnable::resetTimeout

class $Mocha
  constructor: (@Cypress, specWindow) ->
    reporter = $Cypress.reporter ? ->

    @mocha = new Mocha
      reporter: reporter
      enableTimeouts: false

    @override()
    @listeners()

    @specWindow = specWindow

    @set(specWindow)

  override: ->
    ## these should probably be class methods
    ## since they alter the global Mocha and
    ## are not localized to this mocha instance
    @patchRunnerFail()
    @patchRunnableRun()
    @patchRunnableResetTimeout()

    return @

  listeners: ->
    @listenTo @Cypress, "abort", =>
      ## during abort we always want to reset
      ## the mocha instance grep to all
      ## so its picked back up by mocha
      ## naturally when the iframe spec reloads
      @grep /.*/

    @listenTo @Cypress, "stop", => @stop()

    return @

  ## pass our options down to the runner
  options: (runner) ->
    runner.options(@mocha.options)

  grep: (re) ->
    @mocha.grep(re)

  getRunner: ->
    _this = @

    Runner::run = ->
      ## reset our runner#run function
      ## so the next time we call it
      ## its normal again!
      _this.restoreRunnerRun()

      ## return the runner instance
      return @

    @mocha.run()

  patchRunnerFail: ->
    ## matching the current Runner.prototype.fail except
    ## changing the logic for determing whether this is a valid err
    Runner::fail = _.wrap runnerFail, (orig, runnable, err) ->
      ## if this isnt a correct error object then just bail
      ## and call the original function
      if Object.prototype.toString.call(err) isnt "[object Error]"
        return orig.call(@, runnable, err)

      ## else replicate the normal mocha functionality
      ++@failures

      runnable.state = "failed"

      @emit("fail", runnable, err)

  patchRunnableRun: ->
    _this = @
    Cypress = @Cypress

    Runnable::run = _.wrap runnableRun, (orig, args...) ->

      runnable = @

      ## if cy was enqueued within the test
      ## then we know we should forcibly return cy
      invokedCy = _.once ->
        runnable._invokedCy = true

      @fn = _.wrap @fn, (orig, args...) ->
        _this.listenTo Cypress, "enqueue", invokedCy

        unbind = ->
          _this.stopListening Cypress, "enqueue", invokedCy
          runnable.fn = orig

        try
          ## call the original function with
          ## our called ctx (from mocha)
          ## and apply the new args in case
          ## we have a done callback
          result = orig.apply(@, args)

          unbind()

          ## if we invoked cy in this function
          ## then forcibly return last cy chain
          if runnable._invokedCy
            return Cypress.cy.state("chain")

          ## else return regular result
          return result
        catch e
          unbind()
          throw e

      orig.apply(@, args)

  patchRunnableResetTimeout: ->
    Runnable::resetTimeout = _.wrap runnableResetTimeout, (orig) ->
      runnable = @

      ms = @timeout() or 1e9

      @clearTimeout()

      getErrPath = ->
        ## we've yield an explicit done callback
        if runnable.async
          "mocha.async_timed_out"
        else
          "mocha.timed_out"

      @timer = setTimeout ->
        errMessage = utils.errMessageByPath(getErrPath(), { ms })
        runnable.callback new Error(errMessage)
        runnable.timedOut = true
      , ms

  set: (contentWindow) ->
    ## create our own mocha objects from our parents if its not already defined
    ## Mocha is needed for the id generator
    contentWindow.Mocha ?= Mocha
    contentWindow.mocha ?= @mocha

    @clone(contentWindow)

    ## this needs to be part of the configuration of cypress.json
    ## we can't just forcibly use bdd
    @ui(contentWindow, "bdd")

  clone: (contentWindow) ->
    mocha = contentWindow.mocha

    ## remove all of the listeners from the previous root suite
    @mocha.suite.removeAllListeners()

    ## We clone the outermost root level suite - and replace
    ## the existing root suite with a new one. this wipes out
    ## all references to hooks / tests / suites and thus
    ## prevents holding reference to old suites / tests
    @mocha.suite = mocha.suite.clone()

  ui: (contentWindow, name) ->
    mocha = contentWindow.mocha

    ## Override mocha.ui so that the pre-require event is emitted
    ## with the iframe's `window` reference, rather than the parent's.
    mocha.ui = (name) ->
      @_ui = Mocha.interfaces[name]
      utils.throwErrByPath("mocha.invalid_interface", { args: { name } }) if not @_ui
      @_ui = @_ui(@suite)
      @suite.emit 'pre-require', contentWindow, null, @
      return @

    mocha.ui name

  stop: ->
    @stopListening()
    @restore()

    ## remove any listeners from the mocha.suite
    @mocha.suite.removeAllListeners()

    @mocha.suite.suites = []
    @mocha.suite.tests  = []

    ## null it out to break any references
    @mocha.suite = null

    @Cypress.mocha = null

    delete @specWindow.mocha
    delete @specWindow
    delete @mocha

    return @

  restore: ->
    @restoreRunnerRun()
    @restoreRunnerFail()
    @restoreRunnableRun()
    @restoreRunnableResetTimeout()

    return @

  restoreRunnableResetTimeout: ->
    Runnable::resetTimeout = runnableResetTimeout

  restoreRunnerRun: ->
    Runner::run = runnerRun

  restoreRunnerFail: ->
    Runner::fail = runnerFail

  restoreRunnableRun: ->
    Runnable::run = runnableRun

  _.extend $Mocha.prototype, Backbone.Events

  @create = (Cypress, specWindow) ->
    ## clear out existing listeners
    ## if we already exist!
    if existing = Cypress.mocha
      existing.stopListening()

    ## we dont want the default global mocha instance on our window
    delete window.mocha
    Cypress.mocha = new $Mocha Cypress, specWindow

module.exports = $Mocha
