_          = require("lodash")
os         = require("os")
chalk      = require("chalk")
Promise    = require("bluebird")
headless   = require("./headless")
api        = require("../api")
logger     = require("../logger")
errors     = require("../errors")
stdout     = require("../stdout")
upload     = require("../upload")
Project    = require("../project")
git        = require("../util/git")
terminal   = require("../util/terminal")
ciProvider = require("../util/ci_provider")

logException = (err) ->
  ## give us up to 1 second to
  ## create this exception report
  logger.createException(err)
  .timeout(1000)
  .catch ->
    ## dont yell about any errors either

module.exports = {
  getBranch: (repo) ->
    for branch in ["CIRCLE_BRANCH", "TRAVIS_BRANCH", "CI_BRANCH"]
      if b = process.env[branch]
        return Promise.resolve(b)

    repo.getBranch()

  generateProjectBuildId: (projectId, projectPath, projectName, projectToken) ->
    if not projectToken
      return errors.throw("CI_KEY_MISSING")

    repo = git.init(projectPath)

    Promise.props({
      sha:     repo.getSha()
      email:   repo.getEmail()
      author:  repo.getAuthor()
      remote:  repo.getRemoteOrigin()
      branch:  @getBranch(repo)
      message: repo.getMessage()
    })
    .then (git) ->
      api.createBuild({
        projectId:         projectId
        projectToken:      projectToken
        commitSha:         git.sha
        commitBranch:      git.branch
        commitAuthorName:  git.author
        commitAuthorEmail: git.email
        commitMessage:     git.message
        remoteOrigin:      git.remote
        ciParams:          ciProvider.params()
        ciProvider:        ciProvider.name()
        ciBuildNumber:     ciProvider.buildNum()
      })
      .catch (err) ->
        switch err.statusCode
          when 401
            projectToken = projectToken.slice(0, 5) + "..." + projectToken.slice(-5)
            errors.throw("CI_KEY_NOT_VALID", projectToken)
          when 404
            errors.throw("CI_PROJECT_NOT_FOUND")
          else
            ## warn the user that assets will be not recorded
            errors.warning("CI_CANNOT_CREATE_BUILD_OR_INSTANCE", err)

            ## report on this exception
            ## and return null
            logException(err)
            .return(null)

  createInstance: (buildId, spec) ->
    api.createInstance({
      buildId: buildId
      spec:    spec
    })
    .catch (err) ->
      errors.warning("CI_CANNOT_CREATE_BUILD_OR_INSTANCE", err)

      ## dont log exceptions if we have a 503 status code
      if err.statusCode isnt 503
        logException(err)
        .return(null)
      else
        null

  upload: (options = {}) ->
    {video, screenshots, videoUrl, screenshotUrls} = options

    uploads = []
    count   = 0

    nums = ->
      count += 1

      chalk.gray("(#{count}/#{uploads.length})")

    send = (pathToFile, url) ->
      success = ->
        console.log("  - Done Uploading #{nums()}", chalk.blue(pathToFile))

      fail = (err) ->
        console.log("  - Failed Uploading #{nums()}", chalk.red(pathToFile))

      uploads.push(
        upload(pathToFile, url)
        .then(success)
        .catch(fail)
      )

    if videoUrl
      send(video, videoUrl)

    if screenshotUrls
      screenshotUrls.forEach (obj) ->
        screenshot = _.find(screenshots, {clientId: obj.clientId})

        send(screenshot.path, obj.uploadUrl)

    if not uploads.length
      console.log("  - Nothing to Upload")

    Promise
    .all(uploads)
    .catch (err) ->
      errors.warning("CI_CANNOT_UPLOAD_ASSETS", err)

      logException(err)

  uploadAssets: (instanceId, stats, stdout) ->
    console.log("")
    console.log("")

    terminal.header("Uploading Assets", {
      color: ["blue"]
    })

    console.log("")

    ## get rid of the path property
    screenshots = _.map stats.screenshots, (screenshot) ->
      _.omit(screenshot, "path")

    api.updateInstance({
      instanceId:   instanceId
      tests:        stats.tests
      passes:       stats.passes
      failures:     stats.failures
      pending:      stats.pending
      duration:     stats.duration
      error:        stats.error
      video:        !!stats.video
      screenshots:  screenshots
      failingTests: stats.failingTests
      cypressConfig: stats.config
      ciProvider:    ciProvider.name()
      stdout:       stdout
    })
    .then (resp = {}) =>
      @upload({
        video:          stats.video
        screenshots:    stats.screenshots
        videoUrl:       resp.videoUploadUrl
        screenshotUrls: resp.screenshotUploadUrls
      })
    .catch (err) ->
      errors.warning("CI_CANNOT_CREATE_BUILD_OR_INSTANCE", err)

      ## dont log exceptions if we have a 503 status code
      if err.statusCode isnt 503
        logException(err)
        .return(null)
      else
        null

  uploadStdout: (instanceId, stdout) ->
    api.updateInstanceStdout({
      instanceId:   instanceId
      stdout:       stdout
    })
    .catch (err) ->
      errors.warning("CI_CANNOT_CREATE_BUILD_OR_INSTANCE", err)

      ## dont log exceptions if we have a 503 status code
      logException(err) unless err.statusCode is 503

  run: (options) ->
    {projectPath} = options

    captured = stdout.capture()

    ## if we are using the ci flag that means
    ## we have an old version of the CLI tools installed
    ## and that we need to warn the user what to update
    if options.ci
      type = switch
        when process.env.CYPRESS_CI_KEY
          "DEPRECATED_CYPRESS_CI_ENV_VAR"
        else
          "DEPRECATED_CYPRESS_CI"

      errors.warning(type)

    Project.add(projectPath)
    .then ->
      Project.id(projectPath)
    .then (projectId) =>
      Project.config(projectPath)
      .then (cfg) =>
        {projectName} = cfg

        @generateProjectBuildId(projectId, projectPath, projectName, options.key)
        .then (buildId) =>
          ## bail if we dont have a buildId
          return if not buildId

          @createInstance(buildId, options.spec)
        .then (instanceId) =>
          ## dont check that the user is logged in
          options.ensureAuthToken = false

          ## dont let headless say its all done
          options.allDone       = false

          didUploadAssets       = false

          headless.run(options)
          .then (stats = {}) =>
            ## if we got a instanceId then attempt to
            ## upload these assets
            if instanceId
              @uploadAssets(instanceId, stats, captured.toString())
              .then (ret) ->
                didUploadAssets = ret isnt null
              .return(stats)
              .finally =>
                headless.allDone()

                if didUploadAssets
                  stdout.restore()
                  @uploadStdout(instanceId, captured.toString())

            else
              stdout.restore()
              headless.allDone()
              return stats
}
