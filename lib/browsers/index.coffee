_             = require("lodash")
fs            = require("fs-extra")
path          = require("path")
Promise       = require("bluebird")
launcher      = require("@cypress/core-launcher")
savedState    = require("../saved_state")
utils         = require("./utils")

fs              = Promise.promisifyAll(fs)
instance        = null

kill = (unbind) ->
  ## cleanup our running browser
  ## instance
  return Promise.resolve() if not instance

  new Promise (resolve) ->
    if unbind
      instance.removeAllListeners()

    instance.once("exit", resolve)

    instance.kill()
    cleanup()

cleanup = ->
  instance = null

process.once "exit", kill

browsers = {
  chrome:   require("./chrome")
  electron: require("./electron")
}

## normalize all the chrome* browsers
browsers.chromium = browsers.canary = browsers.chrome

module.exports = {
  get: utils.getBrowsers

  launch: utils.launch

  close: kill

  open: (name, automation, config = {}, options = {}) ->
    kill(true)
    .then ->
      _.defaults options,
        browserArgs: []
        onBrowserOpen: ->
        onBrowserClose: ->

      if not browser = browsers[name]
        keys = _.keys(browsers).join(", ")
        throw new Error("Browser: #{name} has not been added. Available browsers are: #{keys}")

      if not url = options.url
        throw new Error("options.url must be provided when opening a browser. You passed:", options)

      browser.open(name, url, automation, config, options)
      .then (i) ->
        ## TODO: bind to process.exit here
        ## or move this functionality into cypress-core-launder

        instance = i

        ## TODO: normalizing opening and closing / exiting
        ## so that there is a default for each browser but
        ## enable the browser to configure the interface
        instance.once "exit", ->
          options.onBrowserClose()
          cleanup()

        ## TODO: instead of waiting an arbitrary
        ## amount of time here we could instead
        ## wait for the socket.io connect event
        ## which would mean that our browser is
        ## completely rendered and open. that would
        ## mean moving this code out of here and
        ## into the project itself
        ## (just like headless code)
        ## ----------------------------
        ## give a little padding around
        ## the browser opening
        Promise.delay(1000)
        .then ->
          options.onBrowserOpen()

          return instance

}
