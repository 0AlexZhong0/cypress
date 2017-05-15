# require("../spec_helper")
#
# _            = require("lodash")
# os           = require("os")
# path         = require("path")
# uuid         = require("node-uuid")
# Promise      = require("bluebird")
# socketIo     = require("#{root}../../packages/socket")
# extension    = require("#{root}../../packages/extension")
# httpsAgent   = require("https-proxy-agent")
# open         = require("#{root}lib/util/open")
# errors       = require("#{root}lib/errors")
# config       = require("#{root}lib/config")
# Socket       = require("#{root}lib/socket")
# Server       = require("#{root}lib/server")
# Watchers     = require("#{root}lib/watchers")
# automation   = require("#{root}lib/automation")
# Fixtures     = require("#{root}/test/support/helpers/fixtures")
# exec         = require("#{root}lib/exec")
# savedState   = require("#{root}lib/saved_state")
#
# describe "lib/socket", ->
#   beforeEach ->
#     Fixtures.scaffold()
#
#     @todosPath = Fixtures.projectPath("todos")
#     @server    = Server(@todosPath)
#
#     config.get(@todosPath)
#     .then (@cfg) =>
#
#   afterEach ->
#     Fixtures.remove()
#     @server.close()
#
#   context "integration", ->
#     beforeEach (done) ->
#       ## create a for realz socket.io connection
#       ## so we can test server emit / client emit events
#       @server.open(@cfg)
#       .then =>
#         @options = {
#           onSavedStateChanged: @sandbox.spy()
#         }
#
#         @watchers = {
#           watch: ->
#         }
#
#         @automation = automation.create()
#
#         @server.startWebsockets(@watchers, @automation, @cfg, @options)
#         @socket = @server._socket
#
#         done = _.once(done)
#
#         ## when our real client connects then we're done
#         @socket.io.on "connection", (socket) =>
#           @socketClient = socket
#           done()
#
#         {proxyUrl, socketIoRoute} = @cfg
#
#         ## force node into legit proxy mode like a browser
#         agent = new httpsAgent("http://localhost:#{@cfg.port}")
#
#         @client = socketIo.client(proxyUrl, {
#           agent: agent
#           path: socketIoRoute
#           transports: ["websocket"]
#         })
#
#     afterEach ->
#       @client.disconnect()
#
#     context "on(automation:request)", ->
#       describe "#onAutomation", ->
#         before ->
#           global.chrome = {
#             cookies: {
#               set: ->
#               getAll: ->
#               remove: ->
#               onChanged: {
#                 addListener: ->
#               }
#             }
#             runtime: {
#
#             }
#             tabs: {
#               query: ->
#               executeScript: ->
#             }
#           }
#
#         beforeEach (done) ->
#           @socket.io.on "connection", (@extClient) =>
#             @extClient.on "automation:client:connected", ->
#               done()
#
#           extension.connect(@cfg.proxyUrl, @cfg.socketIoRoute, socketIo.client)
#
#         afterEach ->
#           @extClient.disconnect()
#
#         after ->
#           delete global.chrome
#
#         it "does not return cypress namespace or socket io cookies", (done) ->
#           @sandbox.stub(chrome.cookies, "getAll")
#           .withArgs({domain: "localhost"})
#           .yieldsAsync([
#             {name: "foo", value: "f", path: "/", domain: "localhost", secure: true, httpOnly: true, expirationDate: 123, a: "a", b: "c"}
#             {name: "bar", value: "b", path: "/", domain: "localhost", secure: false, httpOnly: false, expirationDate: 456, c: "a", d: "c"}
#             {name: "__cypress.foo", value: "b", path: "/", domain: "localhost", secure: false, httpOnly: false, expirationDate: 456, c: "a", d: "c"}
#             {name: "__cypress.bar", value: "b", path: "/", domain: "localhost", secure: false, httpOnly: false, expirationDate: 456, c: "a", d: "c"}
#             {name: "__socket.io", value: "b", path: "/", domain: "localhost", secure: false, httpOnly: false, expirationDate: 456, c: "a", d: "c"}
#           ])
#
#           @client.emit "automation:request", "get:cookies", {domain: "localhost"}, (resp) ->
#             expect(resp).to.deep.eq({
#               response: [
#                 {name: "foo", value: "f", path: "/", domain: "localhost", secure: true, httpOnly: true, expiry: 123}
#                 {name: "bar", value: "b", path: "/", domain: "localhost", secure: false, httpOnly: false, expiry: 456}
#               ]
#             })
#             done()
#
#         it "does not clear any namespaced cookies", (done) ->
#           @sandbox.stub(chrome.cookies, "getAll")
#           .withArgs({name: "session"})
#           .yieldsAsync([
#             {name: "session", value: "key", path: "/", domain: "google.com", secure: true, httpOnly: true, expirationDate: 123, a: "a", b: "c"}
#           ])
#
#           @sandbox.stub(chrome.cookies, "remove")
#           .withArgs({name: "session", url: "https://google.com/"})
#           .yieldsAsync(
#             {name: "session", url: "https://google.com/", storeId: "123"}
#           )
#
#           cookies = [
#             {name: "session", value: "key", path: "/", domain: "google.com", secure: true, httpOnly: true, expiry: 123}
#             {domain: "localhost", name: "__cypress.initial", value: true}
#             {domain: "localhost", name: "__socket.io", value: "123abc"}
#           ]
#
#           @client.emit "automation:request", "clear:cookies", cookies, (resp) ->
#             expect(resp).to.deep.eq({
#               response: [
#                 {name: "session", value: "key", path: "/", domain: "google.com", secure: true, httpOnly: true, expiry: 123}
#               ]
#             })
#             done()
#
#         it "throws trying to clear namespaced cookie"
#
#         it "throws trying to set a namespaced cookie"
#
#         it "throws trying to get a namespaced cookie"
#
#         it "throws when automation:response has an error in it"
#
#         it "throws when no clients connected to automation", (done) ->
#           @extClient.disconnect()
#
#           @client.emit "automation:request", "get:cookies", {domain: "foo"}, (resp) ->
#             expect(resp.__error).to.eq("Could not process 'get:cookies'. No automation servers connected.")
#             done()
#
#         it "returns true when tab matches magic string", (done) ->
#           code = "var s; (s = document.getElementById('__cypress-string')) && s.textContent"
#
#           @sandbox.stub(chrome.tabs, "query")
#           .withArgs({windowType: "normal"})
#           .yieldsAsync([{id: 1, url: "http://localhost"}])
#
#           @sandbox.stub(chrome.tabs, "executeScript")
#           .withArgs(1, {code: code})
#           .yieldsAsync(["string"])
#
#           @client.emit "is:automation:client:connected", {element: "__cypress-string", string: "string"}, (resp) ->
#             expect(resp).to.be.true
#             done()
#
#         it "returns true after retrying", (done) ->
#           err = new Error
#
#           ## just force onAumation to reject up until the 4th call
#           oA = @sandbox.stub(@socket, "onAutomation")
#
#           oA
#           .onCall(0).rejects(err)
#           .onCall(1).rejects(err)
#           .onCall(2).rejects(err)
#           .onCall(3).resolves()
#
#           @client.emit "is:automation:client:connected", {element: "__cypress-string", string: "string"}, (resp) ->
#             expect(oA.callCount).to.be.eq(4)
#
#             expect(resp).to.be.true
#             done()
#
#         it "returns false when times out", (done) ->
#           code = "var s; (s = document.getElementById('__cypress-string')) && s.textContent"
#
#           @sandbox.stub(chrome.tabs, "query")
#           .withArgs({url: "CHANGE_ME_HOST/*", windowType: "normal"})
#           .yieldsAsync([{id: 1}])
#
#           @sandbox.stub(chrome.tabs, "executeScript")
#           .withArgs(1, {code: code})
#           .yieldsAsync(["foobarbaz"])
#
#           ## reduce the timeout so we dont have to wait so long
#           @client.emit "is:automation:client:connected", {element: "__cypress-string", string: "string", timeout: 100}, (resp) ->
#             expect(resp).to.be.false
#             done()
#
#         it "retries multiple times and stops after timing out", (done) ->
#           ## just force onAumation to reject every time its called
#           oA = @sandbox.stub(@socket, "onAutomation").rejects(new Error)
#
#           ## reduce the timeout so we dont have to wait so long
#           @client.emit "is:automation:client:connected", {element: "__cypress-string", string: "string", timeout: 100}, (resp) ->
#             callCount = oA.callCount
#
#             ## it retries every 25ms so explect that
#             ## this function was called at least 2 times
#             expect(callCount).to.be.gt(2)
#
#             expect(resp).to.be.false
#
#             _.delay ->
#               ## wait another 100ms and make sure
#               ## that it was cancelled and not continuously
#               ## retried!
#               ## if we remove Promise.config({cancellation: true})
#               ## then this will fail. bluebird has changed its
#               ## cancellation logic before and so we want to use
#               ## an integration test to ensure this works as expected
#               expect(callCount).to.eq(oA.callCount)
#               done()
#             , 100
#
#       describe "options.onAutomationRequest", ->
#         beforeEach ->
#           @oar = @options.onAutomationRequest = @sandbox.stub()
#
#         it "calls onAutomationRequest with message and data", (done) ->
#           @oar.withArgs("focus", {foo: "bar"}).resolves([])
#
#           @client.emit "automation:request", "focus", {foo: "bar"}, (resp) ->
#             expect(resp).to.deep.eq({response: []})
#             done()
#
#         it "calls callback with error on rejection", ->
#           err = new Error("foo")
#
#           @oar.withArgs("focus", {foo: "bar"}).rejects(err)
#
#           @client.emit "automation:request", "focus", {foo: "bar"}, (resp) ->
#             expect(resp).to.deep.eq({__error: err.message, __name: err.name, __stack: err.stack})
#             done()
#
#         it "does not return __cypress or __socket.io namespaced cookies", ->
#
#         it "throws when onAutomationRequest rejects"
#
#         it "is:automation:client:connected returns true", (done) ->
#           @oar.withArgs("is:automation:client:connected", {string: "foo"}).resolves(true)
#
#           @client.emit "is:automation:client:connected", {string: "foo"}, (resp) ->
#             expect(resp).to.be.true
#             done()
#
#     context "on(automation:push:request)", ->
#       beforeEach (done) ->
#         @socketClient.on "automation:client:connected", -> done()
#
#         @client.emit("automation:client:connected")
#
#       it "emits 'automation:push:message'", (done) ->
#         data = {cause: "explicit", cookie: {name: "foo", value: "bar"}, removed: true}
#
#         emit = @sandbox.stub(@socket.io, "emit")
#
#         @client.emit "automation:push:request", "change:cookie", data, ->
#           expect(emit).to.be.calledWith("automation:push:message", "change:cookie", {
#             cookie: {name: "foo", value: "bar"}
#             message: "Cookie Removed: 'foo=bar'"
#             removed: true
#           })
#           done()
#
#     context "on(open:finder)", ->
#       beforeEach ->
#         @sandbox.stub(open, "opn").resolves()
#
#       it "calls opn with path", (done) ->
#         @client.emit "open:finder", @cfg.parentTestsFolder, =>
#           expect(open.opn).to.be.calledWith(@cfg.parentTestsFolder)
#           done()
#
#     context "on(watch:test:file)", ->
#       it "calls socket#watchTestFileByPath with config, filePath, watchers", (done) ->
#         @sandbox.stub(@socket, "watchTestFileByPath")
#
#         @client.emit "watch:test:file", "path/to/file", =>
#           expect(@socket.watchTestFileByPath).to.be.calledWith(@cfg, "path/to/file", @watchers)
#           done()
#
#     context "on(app:connect)", ->
#       it "calls options.onConnect with socketId and socket", (done) ->
#         @options.onConnect = (socketId, socket) ->
#           expect(socketId).to.eq("sid-123")
#           expect(socket.connected).to.be.true
#           done()
#
#         @client.emit "app:connect", "sid-123"
#
#     context "on(fixture)", ->
#       it "calls socket#onFixture", (done) ->
#         onFixture = @sandbox.stub(@socket, "onFixture").yieldsAsync("bar")
#
#         @client.emit "fixture", "foo", {}, (resp) =>
#           expect(resp).to.eq("bar")
#
#           ## ensure onFixture was called with those same arguments
#           ## therefore we have verified the socket binding and
#           ## the call into onFixture with the proper arguments
#           expect(onFixture).to.be.calledWith(@cfg, "foo")
#           done()
#
#       it "returns the fixture object", ->
#         cb = @sandbox.spy()
#
#         @socket.onFixture(@cfg, "foo", {}, cb).then ->
#           expect(cb).to.be.calledWith [
#             {"json": true}
#           ]
#
#       it "errors when fixtures fails", ->
#         cb = @sandbox.spy()
#
#         @socket.onFixture(@cfg, "does-not-exist.txt", {}, cb).then ->
#           obj = cb.getCall(0).args[0]
#           expect(obj).to.have.property("__error")
#           expect(obj.__error).to.include "No fixture exists at:"
#
#     context "on(request)", ->
#       it "calls socket#onRequest", (done) ->
#         @sandbox.stub(@options, "onRequest").resolves({foo: "bar"})
#
#         @client.emit "request", "foo", (resp) ->
#           expect(resp).to.deep.eq({foo: "bar"})
#
#           done()
#
#       it "catches errors and clones them", (done) ->
#         err = new Error("foo bar baz")
#
#         @sandbox.stub(@options, "onRequest").rejects(err)
#
#         @client.emit "request", "foo", (resp) ->
#           expect(resp).to.deep.eq({__error: errors.clone(err)})
#
#           done()
#
#     context "on(exec)", ->
#       it "calls exec#run with project root and options", (done) ->
#         run = @sandbox.stub(exec, "run").returns(Promise.resolve("Desktop Music Pictures"))
#
#         @client.emit "exec", { cmd: "ls" }, (resp) =>
#           expect(run).to.be.calledWith(@cfg.projectRoot, { cmd: "ls" })
#           expect(resp).to.eq("Desktop Music Pictures")
#           done()
#
#       it "errors when execution fails, passing through timedout", (done) ->
#         error = new Error("command not found: lsd")
#         error.timedout = true
#         @sandbox.stub(exec, "run").rejects(error)
#
#         @client.emit "exec", { cmd: "lsd" }, (resp) =>
#           expect(resp.__error).to.equal("command not found: lsd")
#           expect(resp.timedout).to.be.true
#           done()
#
#     context "on(save:app:state)", ->
#       beforeEach ->
#         @setState = @sandbox.stub(savedState, "set").returns(Promise.resolve())
#
#       it "calls savedState#set with the state", ->
#         @client.emit "save:app:state", { reporterWidth: 500 }, =>
#           expect(@setState).to.be.calledWith({ reporterWidth: 500 })
#           done()
#
#       it "calls onSavedStateChanged", ->
#         @client.emit "save:app:state", { reporterWidth: 235 }, =>
#           expect(@options.onSavedStateChanged).to.have.been.called
#           done()
#
#   context "unit", ->
#     beforeEach ->
#       @mockClient = @sandbox.stub({
#         on: ->
#         emit: ->
#       })
#
#       @io = {
#         of: @sandbox.stub().returns({on: ->})
#         on: @sandbox.stub().withArgs("connection").yields(@mockClient)
#         emit: @sandbox.stub()
#         close: @sandbox.stub()
#       }
#
#       @sandbox.stub(Socket.prototype, "createIo").returns(@io)
#
#       @server.open(@cfg)
#       .then =>
#         @server.startWebsockets({}, @cfg, {})
#
#         @socket = @server._socket
#
#     context "#close", ->
#       beforeEach ->
#         @server.startWebsockets({}, @cfg, {})
#         @socket = @server._socket
#
#       it "calls close on #io", ->
#         @socket.close()
#         expect(@socket.io.close).to.be.called
#
#       it "does not error when io isnt defined", ->
#         @socket.close()
#
#     context "#watchTestFileByPath", ->
#       beforeEach ->
#         @socket.testsDir = Fixtures.project "todos/tests"
#         @filePath        = @socket.testsDir + "/test1.js"
#         @watchers        = Watchers()
#
#         @sandbox.stub(@watchers, "watchBundle").resolves()
#
#       it "returns undefined if config.watchForFileChanges is false", ->
#         @cfg.watchForFileChanges = false
#         result = @socket.watchTestFileByPath(@cfg, "integration/test1.js", @watchers)
#         expect(result).to.be.undefined
#
#       it "returns undefined if #testFilePath matches arguments", ->
#         @socket.testFilePath = "tests/test1.js"
#         result = @socket.watchTestFileByPath(@cfg, "integration/test1.js", @watchers)
#         expect(result).to.be.undefined
#
#       it "closes existing watched test file", ->
#         remove = @sandbox.stub(@watchers, "removeBundle")
#         @socket.testFilePath = "tests/test1.js"
#         @socket.watchTestFileByPath(@cfg, "test2.js", @watchers).then ->
#           expect(remove).to.be.calledWithMatch("test1.js")
#
#       it "sets #testFilePath", ->
#         @socket.watchTestFileByPath(@cfg, "integration/test1.js", @watchers).then =>
#           expect(@socket.testFilePath).to.eq "tests/test1.js"
#
#       it "can normalizes leading slash", ->
#         @socket.watchTestFileByPath(@cfg, "/integration/test1.js", @watchers).then =>
#           expect(@socket.testFilePath).to.eq "tests/test1.js"
#
#       it "watches file by path", ->
#         @socket.watchTestFileByPath(@cfg, "integration/test2.coffee", @watchers)
#         expect(@watchers.watchBundle).to.be.calledWith("tests/test2.coffee", @cfg)
#
#     context "#startListening", ->
#       it "sets #testsDir", ->
#         @cfg.integrationFolder = path.join(@todosPath, "does-not-exist")
#
#         @socket.startListening(@server.getHttpServer(), {}, @cfg, {})
#         expect(@socket.testsDir).to.eq @cfg.integrationFolder
#
#       describe "watch:test:file", ->
#         it "listens for watch:test:file event", ->
#           @socket.startListening(@server.getHttpServer(), {}, @cfg, {})
#           expect(@mockClient.on).to.be.calledWith("watch:test:file")
#
#         it "passes filePath to #watchTestFileByPath", ->
#           watchers = {}
#           watchTestFileByPath = @sandbox.stub(@socket, "watchTestFileByPath")
#
#           @mockClient.on.withArgs("watch:test:file").yields("foo/bar/baz")
#
#           @socket.startListening(@server.getHttpServer(), watchers, @cfg, {})
#           expect(watchTestFileByPath).to.be.calledWith @cfg, "foo/bar/baz", watchers
#
#       describe "#onTestFileChange", ->
#         beforeEach ->
#           @sandbox.spy(fs, "statAsync")
#
#         it "does not emit if not a js or coffee files", ->
#           @socket.onTestFileChange("foo/bar")
#           expect(fs.statAsync).not.to.be.called
#
#         it "does not emit if a tmp file", ->
#           @socket.onTestFileChange("foo/subl-123.js.tmp")
#           expect(fs.statAsync).not.to.be.called
#
#         it "calls statAsync on .js file", ->
#           @socket.onTestFileChange("foo/bar.js").catch(->).then =>
#             expect(fs.statAsync).to.be.calledWith("foo/bar.js")
#
#         it "calls statAsync on .coffee file", ->
#           @socket.onTestFileChange("foo/bar.coffee").then =>
#             expect(fs.statAsync).to.be.calledWith("foo/bar.coffee")
#
#         it "does not emit if stat throws", ->
#           @socket.onTestFileChange("foo/bar.js").then =>
#             expect(@io.emit).not.to.be.called
