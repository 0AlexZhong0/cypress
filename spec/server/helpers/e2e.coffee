require("../spec_helper")

_          = require("lodash")
fs         = require("fs-extra")
cp         = require("child_process")
path       = require("path")
http       = require("http")
morgan     = require("morgan")
express    = require("express")
Promise    = require("bluebird")
Fixtures   = require("../helpers/fixtures")
user       = require("#{root}lib/user")
cypress    = require("#{root}lib/cypress")
Project    = require("#{root}lib/project")
settings   = require("#{root}lib/util/settings")

cp = Promise.promisifyAll(cp)
fs = Promise.promisifyAll(fs)

env = process.env

e2ePath = Fixtures.projectPath("e2e")

startServer = (obj) ->
  {onServer, port} = obj

  app = express()

  srv = http.Server(app)

  app.use(morgan("dev"))

  if s = obj.static
    opts = if _.isObject(s) then s else {}
    app.use(express.static(e2ePath, opts))

  new Promise (resolve) ->
    srv.listen port, =>
      console.log "listening on port: #{port}"
      onServer?(app)

      resolve(srv)

stopServer = (srv) ->
  new Promise (resolve) ->
    srv.close(resolve)

module.exports = {
  setup: (options = {}) ->
    if options.npmInstall
      before ->
        ## npm install needs extra time
        @timeout(300000)

        cp.execAsync("npm install", {
          cwd: Fixtures.path("projects/e2e")
          maxBuffer: 1024*1000
        })
        .then ->
          ## symlinks mess up fs.copySync
          ## and bin files aren't necessary for these tests
          fs.removeAsync(Fixtures.path("projects/e2e/node_modules/.bin"))

      after ->
        fs.removeAsync(Fixtures.path("projects/e2e/node_modules"))

    beforeEach ->
      Fixtures.scaffold()

      @sandbox.stub(process, "exit")

      user.set({name: "brian", sessionToken: "session-123"})
      .then =>
        Project.add(e2ePath)
      .then =>
        if servers = options.servers
          servers = [].concat(servers)

          Promise.map(servers, startServer)
          .then (servers) =>
            @servers = servers
        else
          @servers = null
      .then =>
        if s = options.settings
          settings.write(e2ePath, s)

    afterEach ->
      Fixtures.remove()

      if s = @servers
        Promise.map(s, stopServer)

  options: (ctx, options = {}) ->
    _.defaults(options, {
      project: e2ePath
      timeout: if options.debug then 3000000 else 45000
    })

    ctx.timeout(options.timeout)

    if spec = options.spec
      ## normalize the path to the spec
      options.spec = spec = path.join("cypress", "integration", spec)

    return options

  args: (options = {}) ->
    args = ["--run-project=#{options.project}"]

    if options.spec
      args.push("--spec=#{options.spec}")

    if options.port
      args.push("--port=#{options.port}")

    if options.hosts
      args.push("--hosts=#{options.hosts}")

    if options.debug
      args.push("--show-headless-gui")

    if options.reporter
      args.push("--reporter=#{options.reporter}")

    if options.reporterOptions
      args.push("--reporter-options=#{options.reporterOptions}")

    if browser = env.BROWSER
      args.push("--browser=#{browser}")

    return args

  start: (ctx, options = {}) ->
    options = @options(ctx, options)
    args    = @args(options)

    cypress.start(args)
    .then ->
      if (code = options.expectedExitCode)?
        expect(process.exit).to.be.calledWith(code)

  exec: (ctx, options = {}) ->
    options = @options(ctx, options)
    args    = @args(options)

    args = ["index.js"].concat(args)

    stdout = ""
    stderr = ""

    new Promise (resolve, reject) ->
      sp = cp.spawn "node", args, {env: _.omit(env, "CYPRESS_DEBUG")}
      sp.stdout.on "data", (buf) ->
        stdout += buf.toString()
      sp.stderr.on "data", (buf) ->
        stderr += buf.toString()
      sp.on "error", reject
      sp.on "exit", (code) ->
        if expected = options.expectedExitCode
          try
            expect(expected).to.eq(code)
          catch err
            return reject(err)

        resolve({
          code:   code
          stdout: stdout
          stderr: stderr
        })
}
