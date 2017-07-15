_ = require("lodash")

builtInCommands = [
  require("../cy/commands/actions/checkbox")
  require("../cy/commands/actions/clicking")
  require("../cy/commands/actions/focus")
  require("../cy/commands/actions/form")
  require("../cy/commands/actions/misc")
  require("../cy/commands/actions/scrolling")
  require("../cy/commands/actions/select")
  require("../cy/commands/actions/text")
  require("../cy/commands/aliasing")
  require("../cy/commands/angular")
  require("../cy/commands/asserting")
  require("../cy/commands/clock")
  require("../cy/commands/commands")
  require("../cy/commands/communications")
  require("../cy/commands/connectors")
  require("../cy/commands/cookies")
  require("../cy/commands/debugging")
  require("../cy/commands/exec")
  require("../cy/commands/files")
  require("../cy/commands/fixtures")
  require("../cy/commands/local_storage")
  require("../cy/commands/location")
  require("../cy/commands/misc")
  require("../cy/commands/navigation")
  require("../cy/commands/querying")
  require("../cy/commands/request")
  require("../cy/commands/sandbox")
  require("../cy/commands/screenshot")
  require("../cy/commands/traversals")
  require("../cy/commands/waiting")
  require("../cy/commands/window")
  require("../cy/commands/xhr")
]

getTypeByPrevSubject = (prevSubject) ->
  switch prevSubject
    when true, "dom"
      "child"
    when "optional"
      "dual"
    else
      "parent"

create = (Cypress, cy, state, config, log) ->
  ## create a single instance
  ## of commands
  commands = {}
  commandBackups = {}

  store = (obj) ->
    commands[obj.key] = obj

  storeOverride = (key, fn) ->
    ## grab the original function if its been backed up
    ## or grab it from the command store
    original = commandBackups[key] or commands[key]

    if not original
      $utils.throwErrByPath("miscellaneous.invalid_overwrite", {
        args: {
          name: key
        }
      })

    ## store the backup again now
    commandBackups[key] = original

    originalFn = original.fn

    overrideFn = _.wrap originalFn, ->
      fn.apply(@, arguments)

    original.fn = overrideFn

  Commands = {
    _commands: commands ## for testing

    each: (fn) ->
      ## perf loop
      for key, command of commands
        fn(command)

      ## prevent loop comprehension
      null

    addAll: (options = {}, obj) ->
      if not obj
        obj = options
        options = {}

      ## perf loop
      for key, fn of obj
        Commands.add(key, options, fn)

      ## prevent loop comprehension
      null

    add: (key, options, fn) ->
      if _.isFunction(options)
        fn = options
        options = {}

      type = getTypeByPrevSubject(options.prevSubject)

      ## should we enforce the prev subject be DOM?
      enforceDom = options.prevSubject is "dom"

      store({
        key
        fn
        type
        enforceDom
      })

    addAssertion: (obj) ->
      ## perf loop
      for key, fn of obj
        store({
          key
          fn,
          type: "assertion"
        })

      ## prevent loop comprehension
      null

    addUtility: (obj) ->
      ## perf loop
      for key, fn of obj
        store({
          key
          fn,
          type: "utility"
        })

      ## prevent loop comprehension
      null

    overwrite: (key, fn) ->
      storeOverride(key, fn)
  }

  ## perf loop
  for cmd in builtInCommands
    cmd(Commands, Cypress, cy, state, config, log)

  return Commands

module.exports = {
  create
}
