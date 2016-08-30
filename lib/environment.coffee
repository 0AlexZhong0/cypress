require("./util/http_overrides")

os      = require("os")
fs      = require("fs-extra")
cwd     = require("./cwd")
Promise = require("bluebird")

Promise.config({cancellation: true})

## never cut off stack traces
Error.stackTraceLimit = Infinity

## cannot use relative require statement
## here because when obfuscated package
## would not be available
pkg = cwd("package.json")

try
  ## i wish we didn't have to do this but we have to append
  ## these command line switches immediately
  app = require("electron").app
  app.commandLine.appendSwitch("disable-renderer-backgrounding", true)
  app.commandLine.appendSwitch("ignore-certificate-errors", true)

  if os.platform() is "linux"
    app.disableHardwareAcceleration()

getEnv = ->
  ## instead of setting NODE_ENV we will
  ## use our own separate CYPRESS_ENV so
  ## as not to conflict with CI providers

  ## use env from package first
  ## or development as default
  process.env["CYPRESS_ENV"] or= fs.readJsonSync(pkg).env ? "development"

module.exports = getEnv()
