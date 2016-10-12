$Cypress.register "LocalStorage", (Cypress, _, $) ->

  clearLocalStorage = (keys) ->
    local = window.localStorage
    remote = @private("window").localStorage

    ## set our localStorage and the remote localStorage
    Cypress.LocalStorage.setStorages(local, remote)

    ## clear the keys
    Cypress.LocalStorage.clear(keys)

    ## and then unset the references
    Cypress.LocalStorage.unsetStorages()

    ## return the remote localStorage object
    return remote

  Cypress.on "test:before:hooks", ->
    try
      ## this may fail if the current
      ## window is bound to another origin
      clearLocalStorage.call(@, [])
    catch
      null

  Cypress.addParentCommand

    clearLocalStorage: (keys) ->
      ## bail if we have keys and we're not a string and we're not a regexp
      if keys and not _.isString(keys) and not _.isRegExp(keys)
        $Cypress.Utils.throwErrByPath("clearLocalStorage.invalid_argument")

      remote = clearLocalStorage.call(@, keys)

      Cypress.Log.command
        name: "clear ls"
        snapshot: true
        end: true

      ## return the remote local storage object
      return remote
