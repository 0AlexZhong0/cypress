/**
 * See comment at top of various_failures_spec.js for more info
 * This covers the same errors but inside custom commands
 */

import outsideError from '../../../todos/throws-error'
import { setup, fail, verify, verifyInternalError } from '../support/util'

setup({ verifyStackLineIsSpecFile: false })

describe('assertion failure', function () {
  fail(this, () => {
    cy.failAssertion()
  })

  verify(this, {
    column: 3,
    codeFrameText: 'add(\'failAssertion\'',
    message: 'expected true to be false',
  })
})

context('exceptions', function () {
  describe('in commands file', function () {
    fail(this, () => {
      cy.failException()
    })

    verify(this, {
      column: 8,
      codeFrameText: 'add(\'failException\'',
      message: 'bar is not a function',
    })
  })

  describe('in file outside project', function () {
    fail(this, () => {
      outsideError()
    })

    verify(this, {
      message: 'An outside error',
      regex: /todos\/throws\-error\.js:5:9/,
      codeFrameText: `thrownewError('An outside error')`,
    })
  })
})

context('commands', function () {
  describe('failure', function () {
    fail(this, () => {
      cy.failCommand()
    })

    verify(this, {
      column: 6,
      codeFrameText: 'add(\'failCommand\'',
      message: 'Timed out retrying: Expected to find element: #does-not-exist, but never found it',
    })
  })

  describe('chained failure', function () {
    fail(this, () => {
      cy.failChainedCommand()
    })

    verify(this, {
      column: 17,
      codeFrameText: 'add(\'failChainedCommand\'',
      message: 'Timed out retrying: Expected to find element: #does-not-exist, but never found it',
    })
  })
})

context('cy.then', function () {
  describe('assertion failure', function () {
    fail(this, () => {
      cy.failThenAssertion()
    })

    verify(this, {
      column: 5,
      codeFrameText: 'add(\'failThenAssertion\'',
      message: 'expected true to be false',
    })
  })

  describe('exception', function () {
    fail(this, () => {
      cy.failThenException()
    })

    verify(this, {
      column: 10,
      codeFrameText: 'add(\'failThenException\'',
      message: 'bar is not a function',
    })
  })

  describe('command failure', function () {
    fail(this, () => {
      cy.failThenCommandFailure()
    })

    verify(this, {
      column: 8,
      codeFrameText: 'add(\'failThenCommandFailure\'',
      message: 'Timed out retrying: Expected to find element: #does-not-exist, but never found it',
    })
  })
})

context('cy.should', function () {
  describe('callback assertion failure', function () {
    fail(this, () => {
      cy.failShouldCallbackAssertion()
    })

    verify(this, {
      column: 5,
      codeFrameText: 'add(\'failShouldCallbackAssertion\'',
      message: 'expected true to be false',
    })
  })

  describe('callback exception', function () {
    fail(this, () => {
      cy.failShouldCallbackException()
    })

    verify(this, {
      column: 10,
      codeFrameText: 'add(\'failShouldCallbackException\'',
      message: 'bar is not a function',
    })
  })

  describe('assertion failure', function () {
    fail(this, () => {
      cy.failShouldAssertion()
    })

    verify(this, {
      column: 4,
      codeFrameText: 'add(\'failShouldAssertion\'',
      message: 'Timed out retrying: expected {} to have property \'foo\'',
    })
  })

  describe('after multiple', function () {
    fail(this, () => {
      cy.failAfterMultipleShoulds()
    })

    verify(this, {
      column: 4,
      codeFrameText: 'add(\'failAfterMultipleShoulds\'',
      message: 'Timed out retrying: expected \'foo\' to equal \'bar\'',
    })
  })

  describe('after multiple callbacks exception', function () {
    fail(this, () => {
      cy.failAfterMultipleShouldCallbacksException()
    })

    verify(this, {
      column: 10,
      codeFrameText: '({}).bar()',
      message: 'bar is not a function',
    })
  })

  describe('after multiple callbacks assertion failure', function () {
    fail(this, () => {
      cy.failAfterMultipleShouldCallbacksAssertion()
    })

    verify(this, {
      column: 5,
      codeFrameText: '.should(()=>',
      message: 'expected true to be false',
    })
  })

  describe('command failure after success', function () {
    fail(this, () => {
      cy.failCommandAfterShouldSuccess()
    })

    verify(this, {
      column: 6,
      codeFrameText: 'add(\'failCommandAfterShouldSuccess\'',
      message: 'Timed out retrying: Expected to find element: #does-not-exist, but never found it',
    })
  })
})

context('cy.each', function () {
  describe('assertion failure', function () {
    fail(this, () => {
      cy.failEachAssertion()
    })

    verify(this, {
      column: 5,
      codeFrameText: 'add(\'failEachAssertion\'',
      message: 'expected true to be false',
    })
  })

  describe('exception', function () {
    fail(this, () => {
      cy.failEachException()
    })

    verify(this, {
      column: 10,
      codeFrameText: 'add(\'failEachException\'',
      message: 'bar is not a function',
    })
  })

  describe('command failure', function () {
    fail(this, () => {
      cy.failEachCommandFailure()
    })

    verify(this, {
      column: 8,
      codeFrameText: 'add(\'failEachCommandFailure\'',
      message: 'Timed out retrying: Expected to find element: #does-not-exist, but never found it',
    })
  })
})

context('cy.spread', function () {
  describe('assertion failure', function () {
    fail(this, () => {
      cy.failSpreadAssertion()
    })

    verify(this, {
      column: 5,
      codeFrameText: 'add(\'failSpreadAssertion\'',
      message: 'expected true to be false',
    })
  })

  describe('exception', function () {
    fail(this, () => {
      cy.failSpreadException()
    })

    verify(this, {
      column: 10,
      codeFrameText: 'add(\'failSpreadException\'',
      message: 'bar is not a function',
    })
  })

  describe('command failure', function () {
    fail(this, () => {
      cy.failSpreadCommandFailure()
    })

    verify(this, {
      column: 8,
      codeFrameText: 'add(\'failSpreadCommandFailure\'',
      message: 'Timed out retrying: Expected to find element: #does-not-exist, but never found it',
    })
  })
})

context('cy.within', function () {
  describe('assertion failure', function () {
    fail(this, () => {
      cy.failWithinAssertion()
    })

    verify(this, {
      column: 5,
      codeFrameText: 'add(\'failWithinAssertion\'',
      message: 'expected true to be false',
    })
  })

  describe('exception', function () {
    fail(this, () => {
      cy.failWithinException()
    })

    verify(this, {
      column: 10,
      codeFrameText: 'add(\'failWithinException\'',
      message: 'bar is not a function',
    })
  })

  describe('command failure', function () {
    fail(this, () => {
      cy.failWithinCommandFailure()
    })

    verify(this, {
      column: 8,
      codeFrameText: 'add(\'failWithinCommandFailure\'',
      message: 'Timed out retrying: Expected to find element: #does-not-exist, but never found it',
    })
  })
})

context('cy.wrap', function () {
  describe('assertion failure', function () {
    fail(this, () => {
      cy.failWrapAssertion()
    })

    verify(this, {
      column: 5,
      codeFrameText: 'add(\'failWrapAssertion\'',
      message: 'expected true to be false',
    })
  })

  describe('exception', function () {
    fail(this, () => {
      cy.failWrapException()
    })

    verify(this, {
      column: 10,
      codeFrameText: 'add(\'failWrapException\'',
      message: 'bar is not a function',
    })
  })

  describe('command failure', function () {
    fail(this, () => {
      cy.failWrapCommandFailure()
    })

    verify(this, {
      column: 8,
      codeFrameText: 'add(\'failWrapCommandFailure\'',
      message: 'Timed out retrying: Expected to find element: #does-not-exist, but never found it',
    })
  })
})

context('cy.visit', function () {
  describe('onBeforeLoad assertion failure', function () {
    fail(this, () => {
      cy.failVisitBeforeLoadAssertion()
    })

    verify(this, {
      column: 7,
      codeFrameText: 'onBeforeLoad',
      message: 'expected true to be false',
    })
  })

  describe('onBeforeLoad exception', function () {
    fail(this, () => {
      cy.failVisitBeforeLoadException()
    })

    verify(this, {
      column: 12,
      codeFrameText: 'onBeforeLoad',
      message: 'bar is not a function',
    })
  })

  describe('onLoad assertion failure', function () {
    fail(this, () => {
      cy.failVisitLoadAssertion()
    })

    verify(this, {
      column: 7,
      codeFrameText: 'onLoad',
      message: 'expected true to be false',
    })
  })

  describe('onLoad exception', function () {
    fail(this, () => {
      cy.failVisitLoadException()
    })

    verify(this, {
      column: 12,
      codeFrameText: 'onLoad',
      message: 'bar is not a function',
    })
  })
})

context('cy.route', function () {
  describe('callback assertion failure', function () {
    fail(this, () => {
      cy.failRouteCallbackAssertion()
    })

    verify(this, {
      column: 5,
      codeFrameText: 'failRouteCallbackAssertion',
      message: 'expected true to be false',
    })
  })

  describe('callback exception', function () {
    fail(this, () => {
      cy.failRouteCallbackException()
    })

    verify(this, {
      column: 10,
      codeFrameText: 'failRouteCallbackException',
      message: '{}.bar is not a function',
    })
  })

  describe('command failure', function () {
    fail(this, () => {
      cy.failRouteCallbackCommandFailure()
    })

    verify(this, {
      column: 8,
      codeFrameText: 'failRouteCallbackCommandFailure',
      message: 'Expected to find element: #does-not-exist, but never found it',
    })
  })

  describe('onAbort assertion failure', function (done) {
    fail(this, () => {
      cy.failRouteOnAbortAssertion()
    })

    verify(this, {
      column: 7,
      codeFrameText: 'onAbort',
      message: 'expected true to be false',
    })
  })

  describe('onAbort exception', function (done) {
    fail(this, () => {
      cy.failRouteOnAbortException()
    })

    verify(this, {
      column: 12,
      codeFrameText: 'onAbort',
      message: '{}.bar is not a function',
    })
  })

  describe('onRequest assertion failure', function (done) {
    fail(this, () => {
      cy.failRouteOnRequestAssertion()
    })

    verify(this, {
      column: 7,
      codeFrameText: 'onRequest',
      message: 'expected true to be false',
    })
  })

  describe('onRequest exception', function (done) {
    fail(this, () => {
      cy.failRouteOnRequestException()
    })

    verify(this, {
      column: 12,
      codeFrameText: 'onRequest',
      message: '{}.bar is not a function',
    })
  })

  describe('onResponse assertion failure', function (done) {
    fail(this, () => {
      cy.failRouteOnResponseAssertion()
    })

    verify(this, {
      column: 7,
      codeFrameText: 'onResponse',
      message: 'expected true to be false',
    })
  })

  describe('onResponse exception', function (done) {
    fail(this, () => {
      cy.failRouteOnResponseException()
    })

    verify(this, {
      column: 12,
      codeFrameText: 'onResponse',
      message: '{}.bar is not a function',
    })
  })
})

context('cy.server', function () {
  describe('onAbort assertion failure', function (done) {
    fail(this, () => {
      cy.failServerOnAbortAssertion()
    })

    verify(this, {
      column: 7,
      codeFrameText: 'onAbort',
      message: 'expected true to be false',
    })
  })

  describe('onAbort exception', function (done) {
    fail(this, () => {
      cy.failServerOnAbortException()
    })

    verify(this, {
      column: 12,
      codeFrameText: 'onAbort',
      message: '{}.bar is not a function',
    })
  })

  describe('onRequest assertion failure', function (done) {
    fail(this, () => {
      cy.failServerOnRequestAssertion()
    })

    verify(this, {
      column: 7,
      codeFrameText: 'onRequest',
      message: 'expected true to be false',
    })
  })

  describe('onRequest exception', function (done) {
    fail(this, () => {
      cy.failServerOnRequestException()
    })

    verify(this, {
      column: 12,
      codeFrameText: 'onRequest',
      message: '{}.bar is not a function',
    })
  })

  describe('onResponse assertion failure', function (done) {
    fail(this, () => {
      cy.failServerOnResponseAssertion()
    })

    verify(this, {
      column: 7,
      codeFrameText: 'onResponse',
      message: 'expected true to be false',
    })
  })

  describe('onResponse exception', function (done) {
    fail(this, () => {
      cy.failServerOnResponseException()
    })

    verify(this, {
      column: 12,
      codeFrameText: 'onResponse',
      message: '{}.bar is not a function',
    })
  })
})

context('cy.readFile', function () {
  describe('existence failure', function () {
    fail(this, () => {
      cy.failReadFileExistence()
    })

    verify(this, {
      column: 6,
      codeFrameText: 'failReadFileExistence',
      message: 'failed because the file does not exist',
    })
  })
})

context('validation errors', function () {
  describe('from cypress', function () {
    fail(this, () => {
      cy.cypressValidationError()
    })

    verify(this, {
      column: 6,
      codeFrameText: 'add(\'cypressValidationError\'',
      message: 'can only accept a string preset or',
      stack: ['throwErrBadArgs', 'From Your Spec Code:'],
    })
  })

  describe('from chai', function () {
    fail(this, () => {
      cy.chaiValidationError()
    })

    verify(this, {
      column: 3,
      codeFrameText: 'add(\'chaiValidationError\'',
      message: 'Invalid Chai property: nope',
      stack: ['proxyGetter', 'From Your Spec Code:'],
    })
  })
})

context('event handlers', function () {
  describe('event assertion failure', function () {
    fail(this, () => {
      cy.failEventHandlerAssertion()
    })

    verify(this, {
      column: 5,
      codeFrameText: 'failEventHandlerAssertion',
      message: 'expected true to be false',
    })
  })

  describe('event exception', function () {
    fail(this, () => {
      cy.failEventHandlerException()
    })

    verify(this, {
      column: 10,
      codeFrameText: 'failEventHandlerException',
      message: '{}.bar is not a function',
    })
  })
})

context('uncaught errors', () => {
  describe('sync app exception', function () {
    fail(this, () => {
      cy.failSyncAppException()
    })

    verify(this, {
      message: [
        'The following error originated from your application code',
        'qux is not defined',
      ],
      regex: /localhost\:\d+\/js_errors.html:\d+:\d+/,
      hasCodeFrame: false,
    })
  })

  describe('async app exception', function () {
    fail(this, () => {
      cy.failAsyncAppException()
    })

    verify(this, {
      message: [
        'The following error originated from your application code',
        'qax is not defined',
      ],
      regex: /localhost\:\d+\/js_errors.html:\d+:\d+/,
      hasCodeFrame: false,
    })
  })

  describe('async exception', function () {
    fail(this, () => {
      cy.failAsyncException()
    })

    verify(this, {
      column: 10,
      message: [
        '{}.bar is not a function',
        'The following error originated from your test code',
      ],
      codeFrameText: 'failAsyncException',
    })
  })

  describe('async exception with done', function () {
    fail(this, (done) => {
      cy.failAsyncException()
    })

    verify(this, {
      column: 10,
      message: [
        '{}.bar is not a function',
        'The following error originated from your test code',
      ],
      codeFrameText: 'failAsyncException',
    })
  })
})

// covering cases where there is a bug in Cypress and we shouldn't show
// the invocation stack. it should show the original stack even if it is
// thrown within a command
context('unexpected errors', () => {
  describe('Cypress method error', function () {
    const isJquery = Cypress.dom.isJquery

    beforeEach(() => {
      Cypress.dom.isJquery = isJquery
    })

    fail(this, () => {
      cy.failInternalCypressMethod()
    })

    verifyInternalError(this, {
      method: 'Cypress.dom.isJquery',
    })
  })

  describe('cy method error', function () {
    const cyExpect = cy.expect

    beforeEach(() => {
      cy.expect = cyExpect
    })

    fail(this, () => {
      cy.failInternalCyMethod()
    })

    verifyInternalError(this, {
      method: 'cy.expect',
    })
  })
})
