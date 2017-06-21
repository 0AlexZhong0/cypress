_         = require("lodash")
fs        = require("fs-extra")
Promise   = require("bluebird")
bumpercar = require("@cypress/bumpercar")
path      = require("path")

fs = Promise.promisifyAll(fs)

PROVIDERS = {
  circle: [
    "cypress-io/cypress-dashboard"
    "cypress-io/cypress-core-example"
    "cypress-io/cypress-core-desktop-gui"
    "cypress-io/cypress-example-kitchensink"
    "cypress-io/cypress-example-todomvc"
    "cypress-io/cypress-example-piechopper"
    "cypress-io/cypress-example-recipes",
    "cypress-io/cypress-example-node-versions"
    "cypress-io/cypress-example-module-api"
  ]

  travis: [
    # "cypress-io/cypress-dashboard"
    "cypress-io/cypress-core-example"
    "cypress-io/cypress-core-desktop-gui"
    "cypress-io/cypress-example-kitchensink"
    "cypress-io/cypress-example-todomvc"
    "cypress-io/cypress-example-piechopper"
    "cypress-io/cypress-example-recipes"
  ]
}

awaitEachProjectAndProvider = (fn) ->
  ciJson = path.join(__dirname, "support/ci.json")
  creds = fs.readJsonSync(ciJson, "utf8")

  fs.readJsonAsync(ciJson)
  .then (creds) ->
    ## configure a new Bumpercar
    car = bumpercar.create({
      providers: {
        travis: {
          githubToken: creds.githubToken
        }
        circle: {
          circleToken: creds.circleToken
        }
      }
    })
  .then ->
    _.map PROVIDERS, (projects, provider) ->
      Promise.map projects, (project) ->
        fn(project, provider)
  .all()

module.exports = {
  version: (version) ->
    awaitEachProjectAndProvider (project, provider) ->
      car.updateProjectEnv(project, provider, {
        CYPRESS_VERSION: version
      })

  run: ->
    awaitEachProjectAndProvider (project, provider) ->
      car.runProject(project, provider)
}
