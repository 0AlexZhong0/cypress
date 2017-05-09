/* global $Cypress, io */

import _ from 'lodash'
import { EventEmitter } from 'events'
import Promise from 'bluebird'
import { action } from 'mobx'

import automation from './automation'
import logger from './logger'
import overrides from './overrides'

const $ = $Cypress.$
// TODO: loadModules should be default true
const Cypress = $Cypress.create({ loadModules: true })
const channel = io.connect({ path: '/__socket.io' })

channel.on('connect', () => {
  channel.emit('runner:connected')
})

const driverToReporterEvents = 'paused'.split(' ')
const driverToLocalAndReporterEvents = 'run:start run:end'.split(' ')
const driverToSocketEvents = 'fixture request history:entries exec resolve:url preserve:run:state read:file write:file'.split(' ')
const driverTestEvents = 'test:before:run test:after:run'.split(' ')
const driverAutomationEvents = 'get:cookies get:cookie set:cookie clear:cookies clear:cookie take:screenshot'.split(' ')
const driverToLocalEvents = 'viewport config stop url:changed page:loading visit:failed'.split(' ')
const socketRerunEvents = 'runner:restart watched:file:changed'.split(' ')

const localBus = new EventEmitter()
// when detached, this will be the socket channel
const reporterBus = new EventEmitter()

export default {
  reporterBus,

  init (state, connectionInfo) {
    channel.emit('is:automation:client:connected', connectionInfo, action('automationEnsured', (isConnected) => {
      state.automation = isConnected ? automation.CONNECTED : automation.MISSING
      channel.on('automation:disconnected', action('automationDisconnected', () => {
        state.automation = automation.DISCONNECTED
      }))
    }))

    channel.on('change:to:url', (url) => {
      window.location.href = url
    })

    channel.on('automation:push:message', (msg, data = {}) => {
      switch (msg) {
        case 'change:cookie':
          Cypress.Cookies.log(data.message, data.cookie, data.removed)
          break
        default:
          break
      }
    })
  },

  start (config) {
    if (config.env === 'development') overrides.overloadMochaRunnerUncaught()

    if (config.socketId) {
      channel.emit('app:connect', config.socketId)
    }

    Cypress.on('message', (msg, data, cb) => {
      channel.emit('client:request', msg, data, cb)
    })

    _.each(driverToSocketEvents, (event) => {
      Cypress.on(event, (...args) => channel.emit(event, ...args))
    })

    Cypress.on('mocha', (event, ...args) => {
      channel.emit('mocha', event, ...args)
    })

    _.each(driverAutomationEvents, (event) => {
      Cypress.on(event, (...args) => channel.emit('automation:request', event, ...args))
    })

    reporterBus.on('focus:tests', this.focusTests)

    Cypress.setConfig(_.pick(config, 'isHeadless', 'numTestsKeptInMemory', 'waitForAnimations', 'animationDistanceThreshold', 'defaultCommandTimeout', 'pageLoadTimeout', 'requestTimeout', 'responseTimeout', 'environmentVariables', 'xhrUrl', 'baseUrl', 'viewportWidth', 'viewportHeight', 'execTimeout', 'screenshotOnHeadlessFailure', 'namespace', 'remote'))

    Cypress.setVersion(config.version)

    Cypress.start()

    this._addListeners(config)
  },

  _runDriver (runner, state) {
    Cypress.run(() => {})

    reporterBus.emit('reporter:start', {
      startTime: Cypress.getStartTime(),
      numPassed: state.passed,
      numFailed: state.failed,
      numPending: state.pending,
      autoScrollingEnabled: state.autoScrollingEnabled,
      scrollTop: state.scrollTop,
    })
  },

  _addListeners (config) {
    Cypress.on('initialized', ({ runner }) => {
      Cypress.on('collect:run:state', () => new Promise((resolve) => {
        reporterBus.emit('reporter:collect:run:state', resolve)
      }))

      // get the current runnable in case we reran mid-test due to a visit
      // to a new domain
      channel.emit('get:existing:run:state', (state = {}) => {
        const runnables = runner.normalizeAll(state.tests)
        const run = () => {
          this._runDriver(runner, state)
        }

        reporterBus.emit('runnables:ready', runnables)

        if (state.numLogs) {
          runner.setNumLogs(state.numLogs)
        }

        if (state.startTime) {
          runner.setStartTime(state.startTime)
        }

        if (state.currentId) {
          // if we have a currentId it means
          // we need to tell the runner to skip
          // ahead to that test
          runner.resumeAtTest(state.currentId, state.emissions)
        }

        if (config.isHeadless && !state.currentId) {
          channel.emit('set:runnables', runnables, run)
        } else {
          run()
        }
      })
    })

    Cypress.on('log', (log) => {
      const displayProps = Cypress.getDisplayPropsForLog(log)
      reporterBus.emit('reporter:log:add', displayProps)
    })

    Cypress.on('log:state:changed', (log) => {
      const displayProps = Cypress.getDisplayPropsForLog(log)
      reporterBus.emit('reporter:log:state:changed', displayProps)
    })

    reporterBus.on('runner:console:error', (testId) => {
      const err = Cypress.getErrorByTestId(testId)
      if (err) {
        logger.clearLog()
        logger.logError(err.stack)
      } else {
        logger.logError('No error found for test id', testId)
      }
    })

    reporterBus.on('runner:console:log', (logId) => {
      const consoleProps = Cypress.getConsolePropsForLogById(logId)
      logger.clearLog()
      logger.logFormatted(consoleProps)
    })

    _.each(driverToReporterEvents, (event) => {
      Cypress.on(event, (...args) => {
        reporterBus.emit(event, ...args)
      })
    })

    _.each(driverTestEvents, (event) => {
      Cypress.on(event, (test) => {
        reporterBus.emit(event, test)
      })
    })

    _.each(driverToLocalAndReporterEvents, (event) => {
      Cypress.on(event, (...args) => {
        localBus.emit(event, ...args)
        reporterBus.emit(event, ...args)
      })
    })

    $(window).on('hashchange', this._reRun.bind(this))

    _.each(driverToLocalEvents, (event) => {
      Cypress.on(event, (...args) => localBus.emit(event, ...args))
    })

    Cypress.on('script:error', (err) => {
      Cypress.abort()
      localBus.emit('script:error', err)
    })

    _.each(socketRerunEvents, (event) => {
      channel.on(event,  this._reRun.bind(this))
    })
    reporterBus.on('runner:restart', this._reRun.bind(this))

    function sendEventIfSnapshotProps (logId, event) {
      const snapshotProps = Cypress.getSnapshotPropsForLogById(logId)

      if (snapshotProps) {
        localBus.emit(event, snapshotProps)
      }
    }

    reporterBus.on('runner:show:snapshot', (logId) => {
      sendEventIfSnapshotProps(logId, 'show:snapshot')
    })

    reporterBus.on('runner:hide:snapshot', this._hideSnapshot.bind(this))

    reporterBus.on('runner:pin:snapshot', (logId) => {
      sendEventIfSnapshotProps(logId, 'pin:snapshot')
    })

    reporterBus.on('runner:unpin:snapshot', this._unpinSnapshot.bind(this))

    reporterBus.on('runner:resume', () => {
      Cypress.trigger('resume:all')
    })

    reporterBus.on('runner:next', () => {
      Cypress.trigger('resume:next')
    })

    reporterBus.on('runner:abort', () => {
      Cypress.abort()
    })

    reporterBus.on('save:state', (state) => {
      this.saveState(state)
    })

    // when we actually unload then
    // nuke all of the cookies again
    // so we clear out unload
    $(window).on('unload', () => {
      this._clearAllCookies()
    })

    // when our window triggers beforeunload
    // we know we've change the URL and we need
    // to clear our cookies
    // additionally we set unload to true so
    // that Cypress knows not to set any more
    // cookies
    $(window).on('beforeunload', () => {
      reporterBus.emit('reporter:restart:test:run')

      this._clearAllCookies()
      this._setUnload()
    })
  },

  run (specPath, specWindow, $autIframe) {
    channel.emit('watch:test:file', specPath)
    Cypress.initialize(specWindow, $autIframe)
  },

  stop () {
    localBus.removeAllListeners()
    Cypress.off()
    channel.off()
    overrides.restore()
  },

  _reRun () {
    // when we are re-running we first
    // need to abort cypress always
    Cypress.abort()
    .then(() => {
      return this._restart()
    })
    .then(() => {
      localBus.emit('restart')
    })
  },

  _restart () {
    return new Promise((resolve) => {
      reporterBus.once('reporter:restarted', resolve)
      reporterBus.emit('reporter:restart:test:run')
    })
  },

  on (event, ...args) {
    localBus.on(event, ...args)
  },

  notifyRunningSpec (specFile) {
    channel.emit('spec:changed', specFile)
  },

  focusTests () {
    channel.emit('focus:tests')
  },

  snapshotUnpinned () {
    this._unpinSnapshot()
    this._hideSnapshot()
    reporterBus.emit('reporter:snapshot:unpinned')
  },

  _unpinSnapshot () {
    localBus.emit('unpin:snapshot')
  },

  _hideSnapshot () {
    localBus.emit('hide:snapshot')
  },

  launchBrowser (browser) {
    channel.emit('reload:browser', window.location.toString(), browser && browser.name)
  },

  // clear all the cypress specific cookies
  // whenever our app starts
  // and additional when we stop running our tests
  _clearAllCookies () {
    Cypress.Cookies.clearCypressCookies()
  },

  _setUnload () {
    Cypress.Cookies.setCy('unload', true)
  },

  saveState (state) {
    channel.emit('save:app:state', state)
  },
}
