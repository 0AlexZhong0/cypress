_ = require("lodash")

utils = require("../cypress/utils")

aliasRe = /^@.+/
aliasDisplayRe = /^([@]+)/

blacklist = ["test", "runnable", "timeout", "slow", "skip", "inspect"]

module.exports = ($Cy) ->
  $Cy.extend({
    _validateAlias: (alias) ->
      if not _.isString(alias)
        utils.throwErrByPath "as.invalid_type"

      if _.isBlank(alias)
        utils.throwErrByPath "as.empty_string"

      if alias in blacklist
        utils.throwErrByPath "as.reserved_word", { args: { alias } }

    _addAlias: (aliasObj) ->
      {alias, subject} = aliasObj
      aliases = @state("aliases") ? {}
      aliases[alias] = aliasObj
      @state("aliases", aliases)

      remoteSubject = @_getRemotejQueryInstance(subject)
      ## assign the subject to our runnable ctx
      @assign(alias, remoteSubject ? subject)

    assign: (str, obj) ->
      @privateState("runnable").ctx[str] = obj

    ## these are public because its expected other commands
    ## know about them and are expected to call them
    getNextAlias: ->
      next = @state("current").get("next")
      if next and next.get("name") is "as"
        next.get("args")[0]

    getAlias: (name, cmd, log) ->
      aliases = @state("aliases") ? {}

      ## bail if the name doesnt reference an alias
      return if not aliasRe.test(name)

      ## slice off the '@'
      if not alias = aliases[name.slice(1)]
        @aliasNotFoundFor(name, cmd, log)

      return alias

    _aliasDisplayName: (name) ->
      name.replace(aliasDisplayRe, "")

    getAvailableAliases: ->
      return [] if not aliases = @state("aliases")

      _.keys(aliases)

    aliasNotFoundFor: (name, cmd, log) ->
      availableAliases = @getAvailableAliases()

      ## throw a very specific error if our alias isnt in the right
      ## format, but its word is found in the availableAliases
      if (not aliasRe.test(name)) and (name in availableAliases)
        displayName = @_aliasDisplayName(name)
        utils.throwErrByPath "alias.invalid", {
          onFail: log
          args: { name, displayName }
        }

      cmd ?= log and log.get("name") or @state("current").get("name")
      displayName = @_aliasDisplayName(name)

      errPath = if availableAliases.length
        "alias.not_registered_with_available"
      else
        "alias.not_registered_without_available"

      utils.throwErrByPath errPath, {
        onFail: log
        args: { cmd, displayName, availableAliases: availableAliases.join(", ") }
      }

    _getCommandsUntilFirstParentOrValidSubject: (command, memo = []) ->
      return null if not command

      ## push these onto the beginning of the commands array
      memo.unshift(command)

      ## break and return the memo
      if command.get("type") is "parent" or @_contains(command.get("subject"))
        return memo

      @_getCommandsUntilFirstParentOrValidSubject(command.get("prev"), memo)

    ## recursively inserts previous commands
    _replayFrom: (current) ->
      ## reset each chainerId to the
      ## current value
      chainerId = @state("chainerId")

      insert = (commands) =>
        _.each commands, (cmd) =>
          cmd.set("chainerId", chainerId)

          ## clone the command to prevent
          ## mutating its properties
          @insertCommand cmd.clone()

      ## - starting with the aliased command
      ## - walk up to each prev command
      ## - until you reach a parent command
      ## - or until the subject is in the DOM
      ## - from that command walk down inserting
      ##   every command which changed the subject
      ## - coming upon an assertion should only be
      ##   inserted if the previous command should
      ##   be replayed

      commands = @_getCommandsUntilFirstParentOrValidSubject(current)

      if commands
        initialCommand = commands.shift()

        insert _.reduce commands, (memo, command, index) ->
          push = ->
            memo.push(command)

          switch
            when command.get("type") is "assertion"
              ## if we're an assertion and the prev command
              ## is in the memo, then push this one
              if command.get("prev") in memo
                push()

            when command.get("subject") isnt initialCommand.get("subject")
              ## when our subjects dont match then
              ## reset the initialCommand to this command
              ## so the next commands can compare against
              ## this one to figure out the changing subjects
              initialCommand = command

              push()

          return memo

        , [initialCommand]

  })
    # cy
    #   .server()
    #   .route("/users", {}).as("u")
    #   .query("body").as("b")
    #   .query("div").find("span").find("input").as("i")
    #   .query("form").wait ($form) ->
    #     expect($form).to.contain("foo")
    #   .find("div").find("span:first").find("input").as("i2")
    #   .within "@b", ->
    #     cy.query("button").as("btn")

    ## DIFFICULT ALIASING SCENARIOS
    ## 1. You have a row of 5 todos.  You alias the last row. You insert
    ## a new row.  Does alias point to the NEW last row or the existing one?

    ## 2. There is several action(s) to make up an element.  You click #add
    ## which pops up a form, and alias the form.  You fill out the form and
    ## click submit.  This clears the form.  You then use the form alias.  Does
    ## it repeat the several steps which created the form in the first place?
    ## does it simply say the referenced form cannot be found?

    ## IF AN ALIAS CAN BE FOUND
    ## cy.get("form").find("input[name='age']").as("age")
    ## cy.get("@age").type(28)
    ## GET 'form'
    ##   FIND 'input[name='age']'
    ##     AS 'age'
    ##
    ## GET '@age'
    ##   TYPE '28'
    ##
    ## IF AN ALIAS CANNOT BE FOUND
    ## ALIAS '@age' NO LONGER IN DOCUMENT, REQUERYING, REPLAYING COMMANDS
    ## GET 'form'
    ##   FIND 'input[name='age']'
    ##     TYPE '28'
