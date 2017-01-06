require("../../spec_helper")

extension = require("@cypress/core-extension")
Fixtures = require("../../helpers/fixtures")
project  = require("#{root}../lib/electron/handlers/project")
Project  = require("#{root}../lib/project")
launcher = require("#{root}../lib/launcher")

describe "lib/electron/handlers/projects", ->
  beforeEach ->
    Fixtures.scaffold()

    @todosPath = Fixtures.projectPath("todos")

  afterEach ->
    Fixtures.remove()

    project.close()

  context ".open", ->
    beforeEach ->
      @projectInstance = {
        getConfig: @sandbox.stub().resolves({clientUrlDisplay: "foo", socketIoRoute: "bar"})
        setBrowsers: @sandbox.stub().resolves([])
      }

      @sandbox.stub(launcher, "getBrowsers").resolves([])
      @sandbox.stub(extension, "setHostAndPath").withArgs("foo", "bar").resolves()
      @open = @sandbox.stub(Project.prototype, "open").resolves(@projectInstance)

    it "resolves with opened project instance", ->
      project.open(@todosPath)
      .then (p) =>
        expect(p.projectRoot).to.eq(@todosPath)
        expect(p).to.be.an.instanceOf(Project)

    it "merges options into whitelisted config args", ->
      args = {port: 2222, baseUrl: "localhost", foo: "bar"}
      options = {socketId: 123, port: 2020}
      project.open(@todosPath, args, options)
      .then =>
        expect(@open).to.be.calledWithMatch({
          port: 2020
          socketId: 123
          baseUrl: "localhost"
          sync: true
        })
        expect(@open.getCall(0).args[0].onReloadBrowser).to.be.a("function")

    it "passes onReloadBrowser which calls relaunch with url + browser", ->
      relaunch = @sandbox.stub(project, "relaunch")

      project.open(@todosPath)
      .then =>
        @open.getCall(0).args[0].onReloadBrowser("foo", "bar")
        expect(relaunch).to.be.calledWith("foo", "bar")

    ## TODO: write these tests!!
    it "gets browsers available for launch"

    it "sets browsers on project"

  context ".close", ->
