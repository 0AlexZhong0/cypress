path    = require("path")
utils   = require("../../lib/utils")
Run     = require("../../lib/commands/run")

describe "Run", ->
  context "cli interface", ->
    beforeEach ->
      mockery.registerMock("./commands/run", @spy = @sandbox.spy())
      @parse = (args) ->
        program.parse("node test #{args}".split(" "))

    it "calls run with port", ->
      @parse("run --port 7878")
      expect(@spy).to.be.calledWith(undefined, {port: "7878"})

    it "calls run with spec", ->
      @parse("run myApp --spec cypress/integration/foo_spec.js")
      expect(@spy).to.be.calledWith("myApp", {spec: "cypress/integration/foo_spec.js"})

    it "calls run with port with -p arg", ->
      @parse("run 1234 -p 8989")
      expect(@spy).to.be.calledWith("1234", {port: "8989"})

    it "calls run with env variables", ->
      @parse("run myApp --env foo=bar,host=http://localhost:8888")
      expect(@spy).to.be.calledWith("myApp", {env: "foo=bar,host=http://localhost:8888"})

    it "calls run with config", ->
      @parse("run myApp --config watchForFileChanges=false,baseUrl=localhost")
      expect(@spy).to.be.calledWith("myApp", {config: "watchForFileChanges=false,baseUrl=localhost"})

  context "#constructor", ->
    beforeEach ->
      @spawn  = @sandbox.stub(utils, "spawn")

      @setup = (key, options = {}) ->
        Run(key, options)

    it "spawns --run-project with --ci and --key and xvfb", ->
      @setup(null, {port: "1234"})
      pathToProject = path.resolve(process.cwd(), ".")
      expect(@spawn).to.be.calledWith(["--run-project", pathToProject, "--port", "1234"])

    it "spawns --run-project with --env", ->
      @setup(null, {env: "host=http://localhost:1337,name=brian"})
      pathToProject = path.resolve(process.cwd(), ".")
      expect(@spawn).to.be.calledWith(["--run-project", pathToProject, "--env", "host=http://localhost:1337,name=brian"])

    it "spawns --run-project with --config", ->
      @setup(null, {config: "watchForFileChanges=false,baseUrl=localhost"})
      pathToProject = path.resolve(process.cwd(), ".")
      expect(@spawn).to.be.calledWith(["--run-project", pathToProject, "--config", "watchForFileChanges=false,baseUrl=localhost"])