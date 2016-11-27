cp        = require("child_process")
e2e      = require("../helpers/e2e")
Fixtures = require("../helpers/fixtures")
fs       = require("fs-extra")
path     = require("path")
Promise  = require("bluebird")

fs       = Promise.promisifyAll(fs)
e2ePath  = Fixtures.projectPath("e2e")

describe "e2e reporters", ->
  e2e.setup()

  before ->
    ## npm install needs extra time
    @timeout(30000)
    cp.execSync("npm install", {cwd: Fixtures.path("projects/e2e")})
    ## symlinks mess up fs.copySync
    ## and bin files aren't necessary for these tests
    fs.removeSync(Fixtures.path("projects/e2e/node_modules/.bin"))

  after ->
    fs.removeSync(Fixtures.path("projects/e2e/node_modules"))

  it "supports junit reporter and reporter options", ->
    e2e.start(@, {
      spec: "simple_passing_spec.coffee"
      expectedExitCode: 0
      reporter: "junit"
      reporterOptions: "mochaFile=junit-output/result.xml"
    })
    .then ->
      fs.readFileAsync(path.join(e2ePath, "junit-output", "result.xml"), "utf8")
      .then (str) ->
        expect(str).to.include("<testsuite name=\"simple passing spec\"")
        expect(str).to.include("<testcase name=\"simple passing spec passes\"")

  it "supports local custom reporter", ->
    e2e.exec(@, {
      spec: "simple_passing_spec.coffee"
      expectedExitCode: 0
      reporter: "reporters/custom.js"
    })
    .get("stdout")
    .then (stdout) ->
      expect(stdout).to.include """
        passes
        finished!
      """

  it "supports npm custom reporter", ->
    e2e.exec(@, {
      spec: "simple_passing_spec.coffee"
      expectedExitCode: 0
      reporter: "mochawesome"
    })
    .get("stdout")
    .then (stdout) ->
      expect(stdout).to.include "[mochawesome] Report saved to mochawesome-reports/mochawesome.html"

      fs.readFileAsync(path.join(e2ePath, "mochawesome-reports", "mochawesome.html"), "utf8").then (xml) ->
        expect(xml).to.include("<h3 class=\"suite-title\">simple passing spec</h3>")
        expect(xml).to.include("<div class=\"status-item status-item-passing-pct success\">100% Passing</div>")