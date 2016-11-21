_        = require("lodash")
str      = require("underscore.string")
path     = require("path")
Promise  = require("bluebird")
coerce   = require("./util/coerce")
settings = require("./util/settings")
errors   = require("./errors")
scaffold = require("./scaffold")

## cypress following by _
cypressEnvRe = /^(cypress_)/i
dashesOrUnderscoresRe = /^(_-)+/

folders = "fileServerFolder fixturesFolder integrationFolder screenshotsFolder unitFolder supportFile".split(" ")
configKeys = "port reporter reporterOptions baseUrl execTimeout defaultCommandTimeout pageLoadTimeout requestTimeout responseTimeout numTestsKeptInMemory screenshotOnHeadlessFailure waitForAnimations animationDistanceThreshold watchForFileChanges chromeWebSecurity viewportWidth viewportHeight fileServerFolder fixturesFolder integrationFolder screenshotsFolder environmentVariables hosts supportFile".split(" ")

isCypressEnvLike = (key) ->
  cypressEnvRe.test(key) and key isnt "CYPRESS_ENV"

defaults = {
  port:           null
  hosts:          null
  morgan:         true
  baseUrl:        null
  socketId:       null
  isHeadless:     false
  reporter:       "spec"
  reporterOptions: null
  clientRoute:    "/__/"
  xhrRoute:       "/xhrs/"
  socketIoRoute:  "/__socket.io"
  socketIoCookie: "__socket.io"
  reporterRoute:  "/__cypress/reporter"
  ignoreTestFiles: "*.hot-update.js"
  defaultCommandTimeout: 4000
  requestTimeout:        5000
  responseTimeout:       30000
  pageLoadTimeout:       60000
  execTimeout:           60000
  chromeWebSecurity: true
  waitForAnimations: true
  animationDistanceThreshold: 5
  numTestsKeptInMemory: 50
  watchForFileChanges: true
  screenshotOnHeadlessFailure: true
  autoOpen:       false
  viewportWidth:  1000
  viewportHeight: 660
  fileServerFolder: ""
  # unitFolder:        "cypress/unit"
  supportFile:       "cypress/support/"
  fixturesFolder:    "cypress/fixtures"
  integrationFolder: "cypress/integration"
  screenshotsFolder:  "cypress/screenshots"
  namespace:      "__cypress"

  ## deprecated
  javascripts: []
}

convertRelativeToAbsolutePaths = (projectRoot, obj, defaults = {}) ->
  _.reduce folders, (memo, folder) ->
    val = obj[folder]
    if val?
      memo[folder] = path.resolve(projectRoot, val)
    return memo
  , {}

module.exports = {
  getConfigKeys: -> configKeys

  whitelist: (obj = {}) ->
    _.pick(obj, configKeys)

  get: (projectRoot, options = {}) ->
    Promise.all([
      settings.read(projectRoot)
      settings.readEnv(projectRoot)
    ])
    .spread (settings, envFile) =>
      @set({
        projectName: @getNameFromRoot(projectRoot)
        projectRoot: projectRoot
        config:      settings
        envFile:     envFile
        options:     options
      })

  set: (obj = {}) ->
    {projectRoot, projectName, config, envFile, options} = obj

    ## just force config to be an object
    ## so we dont have to do as much
    ## work in our tests
    config ?= {}

    ## flatten the object's properties
    ## into the master config object
    config.envFile     = envFile
    config.projectRoot = projectRoot
    config.projectName = projectName

    @mergeDefaults(config, options)

  mergeDefaults: (config = {}, options = {}) ->
    resolved = {}

    _.extend config, _.pick(options, "morgan", "isHeadless", "socketId", "report", "browsers")

    _.each @whitelist(options), (val, key) ->
      resolved[key] = "cli"
      config[key] = val
      return

    if url = config.baseUrl
      ## always strip trailing slashes
      config.baseUrl = str.rtrim(url, "/")

    _.defaults config, defaults

    ## split out our own app wide env from user env variables
    ## and delete envFile
    config.environmentVariables = @parseEnv(config, resolved)
    config.env = process.env["CYPRESS_ENV"]
    delete config.envFile

    ## forcibly reset numTestsKeptInMemory
    ## to zero when isHeadless
    if config.isHeadless
      config.numTestsKeptInMemory = 0

    config = @setResolvedConfigValues(config, defaults, resolved)

    if config.port
      config = @setUrls(config)

    config = @setAbsolutePaths(config, defaults)

    config = @setParentTestsPaths(config)

    config = @setScaffoldPaths(config)

    config = @setSupportFileAndFolder(config)

    return config

  setResolvedConfigValues: (config, defaults, resolved) ->
    obj = _.clone(config)

    obj.resolved = @resolveConfigValues(config, defaults, resolved)

    return obj

  resolveConfigValues: (config, defaults, resolved = {}) ->
    ## pick out only the keys found in configKeys
    _.chain(config)
    .pick(configKeys)
    .mapValues (val, key) ->
      source = (s) ->
        {
          value: val
          from:  s
        }

      switch
        when r = resolved[key]
          if _.isObject(r)
            r
          else
            source(r)
        when not _.isEqual(config[key], defaults[key])
          source("config")
        else
          source("default")
    .value()

  setScaffoldPaths: (obj) ->
    obj = _.clone(obj)

    fileName = scaffold.integrationExampleName()

    obj.integrationExampleFile = path.join(obj.integrationFolder, fileName)
    obj.integrationExampleName = fileName

    return obj

  setSupportFileAndFolder: (obj) ->
    obj = _.clone(obj)

    ## if supportFile isn't false
    if sf = obj.supportFile
      ## set config.supportFolder to its directory
      try
        ## resolve full path with extension to
        obj.supportFile = require.resolve(sf)
      catch err
        ## supportFile doesn't exist on disk
        if sf isnt path.resolve(obj.projectRoot, defaults.supportFile)
          ## throw because they have it explicitly set,
          ## so it should be there
          errors.throw("SUPPORT_FILE_NOT_FOUND", sf)
        else
          ## set it to support/index.js, and it will be scaffolded
          ## later in process
          obj.supportFile = path.join(sf, "index.js")

      obj.supportFolder = path.dirname(obj.supportFile)

    return obj

  setParentTestsPaths: (obj) ->
    ## projectRoot:              "/path/to/project"
    ## integrationFolder:        "/path/to/project/cypress/integration"
    ## parentTestsFolder:        "/path/to/project/cypress"
    ## parentTestsFolderDisplay: "project/cypress"

    obj = _.clone(obj)

    ptfd = obj.parentTestsFolder = path.dirname(obj.integrationFolder)

    prd = path.dirname(obj.projectRoot ? "")

    obj.parentTestsFolderDisplay = path.relative(prd, ptfd)

    return obj

  setAbsolutePaths: (obj, defaults) ->
    obj = _.clone(obj)

    ## if we have a projectRoot
    if pr = obj.projectRoot
      ## reset fileServerFolder to be absolute
      # obj.fileServerFolder = path.resolve(pr, obj.fileServerFolder)

      ## and do the same for all the rest
      _.extend obj, convertRelativeToAbsolutePaths(pr, obj, defaults)

    return obj

  setUrls: (obj) ->
    obj = _.clone(obj)

    rootUrl = "http://localhost:" + obj.port

    _.extend obj,
      clientUrlDisplay: rootUrl
      clientUrl:        rootUrl + obj.clientRoute
      reporterUrl:      rootUrl + obj.reporterRoute
      xhrUrl:           obj.namespace + obj.xhrRoute

    return obj

  parseEnv: (cfg, resolved = {}) ->
    envVars = resolved.environmentVariables = {}

    resolveFrom = (from, obj = {}) ->
      _.each obj, (val, key) ->
        envVars[key] = {
          value: val
          from: from
        }

    envCfg  = cfg.env ? {}
    envFile = cfg.envFile ? {}
    envProc = @getProcessEnvVars(process.env) ? {}
    envCLI  = cfg.environmentVariables ? {}

    matchesConfigKey = (key) ->
      if _.has(cfg, key)
        return key

      key = key.toLowerCase().replace(dashesOrUnderscoresRe, "")
      key = str.camelize(key)

      if _.has(cfg, key)
        return key

    configFromEnv = _.reduce envProc, (memo, val, key) ->
      if cfgKey = matchesConfigKey(key)
        ## only change the value if it hasnt been
        ## set by the CLI. override default + config
        if resolved[cfgKey] isnt "cli"
          cfg[cfgKey] = val
          resolved[cfgKey] = {
            value: val
            from: "env"
          }

        memo.push(key)
      memo
    , []

    envProc = _.omit(envProc, configFromEnv)

    resolveFrom("config",  envCfg)
    resolveFrom("envFile", envFile)
    resolveFrom("env",     envProc)
    resolveFrom("cli",     envCLI)

    ## envCfg is from cypress.json
    ## envFile is from cypress.env.json
    ## envProc is from process env vars
    ## envCLI is from CLI arguments
    _.extend envCfg, envFile, envProc, envCLI

  getProcessEnvVars: (obj = {}) ->
    normalize = (key) ->
      key.replace(cypressEnvRe, "")

    _.reduce obj, (memo, value, key) ->
      if isCypressEnvLike(key)
        memo[normalize(key)] = coerce(value)
      memo
    , {}

  getNameFromRoot: (root = "") ->
    path.basename(root)

}
