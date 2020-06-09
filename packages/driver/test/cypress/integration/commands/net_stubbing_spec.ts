import 'cypress/types/net-stubbing'

declare global {
  interface Window {
    $: any
  }
}

const { $, _ } = Cypress

describe('src/cy/commands/net_stubbing', function () {
  const { sinon, state } = Cypress

  beforeEach(function () {
    Cypress.config('experimentalNetworkMocking', true)

    cy.spy(Cypress.utils, 'warning')
  })

  afterEach(function () {
    Cypress.config('experimentalNetworkMocking', false)
  })

  context('#route2', function () {
    it('throws an error if experimentalNetworkMocking is falsy', function (done) {
      Cypress.config('experimentalNetworkMocking', false)

      cy.on('fail', (err) => {
        expect(err.message).to.contain('`cy.route2()` requires experimental network mocking to be enabled.')
        done()
      })

      cy.route2('', '')
    })

    context('creating', function () {
      beforeEach(function () {
        // we don't use cy.spy() because it causes an infinite loop with logging events
        this.sandbox = sinon.createSandbox()
        this.emit = this.sandbox.spy(Cypress, 'emit').withArgs('backend:request', 'net', 'route:added')

        this.testRoute = function (options, handler, expectedEvent, expectedRoute) {
          cy.route2(options, handler).then(function () {
            const handlerId = _.findKey(state('routes'), { handler })
            const route = state('routes')[handlerId!]

            expectedEvent.handlerId = handlerId
            expect(this.emit).to.be.calledWith('backend:request', 'net', 'route:added', expectedEvent)

            expect(route.handler).to.deep.eq(expectedRoute.handler)
            expect(route.options).to.deep.eq(expectedRoute.options)
          })
        }
      })

      afterEach(function () {
        this.sandbox.restore()
      })

      it('emits with url, body and stores Route', function () {
        const handler = 'bar'
        const url = 'http://foo.invalid'
        const expectedEvent = {
          routeMatcher: {
            url: {
              type: 'glob',
              value: url,
            },
          },
          staticResponse: {
            body: 'bar',
          },
        }

        const expectedRoute = {
          options: { url },
          handler,
        }

        this.testRoute(url, handler, expectedEvent, expectedRoute)
      })

      it('emits with url, HTTPController and stores Route', function () {
        const handler = () => {
          return {}
        }

        const url = 'http://foo.invalid'
        const expectedEvent = {
          routeMatcher: {
            url: {
              type: 'glob',
              value: url,
            },
          },
        }

        const expectedRoute = {
          options: { url },
          handler,
        }

        this.testRoute(url, handler, expectedEvent, expectedRoute)
      })

      it('emits with regex values stringified and other values copied and stores Route', function () {
        const handler = () => {
          return {}
        }

        const options = {
          auth: {
            username: 'foo',
            password: /.*/,
          },
          headers: {
            'Accept-Language': /hylian/i,
            'Content-Encoding': 'corrupted',
          },
          hostname: /any.com/,
          https: true,
          method: 'POST',
          path: '/bing?foo',
          pathname: '/bazz',
          port: [1, 2, 3, 4, 5, 6],
          query: {
            bar: 'baz',
            quuz: /(.*)quux/gi,
          },
          url: 'http://foo.invalid',
          webSocket: false,
        }

        const expectedEvent = {
          routeMatcher: {
            auth: {
              username: {
                type: 'glob',
                value: options.auth.username,
              },
              password: {
                type: 'regex',
                value: '/.*/',
              },
            },
            headers: {
              'Accept-Language': {
                type: 'regex',
                value: '/hylian/i',
              },
              'Content-Encoding': {
                type: 'glob',
                value: options.headers['Content-Encoding'],
              },
            },
            hostname: {
              type: 'regex',
              value: '/any.com/',
            },
            https: options.https,
            method: {
              type: 'glob',
              value: options.method,
            },
            path: {
              type: 'glob',
              value: options.path,
            },
            pathname: {
              type: 'glob',
              value: options.pathname,
            },
            port: options.port,
            query: {
              bar: {
                type: 'glob',
                value: options.query.bar,
              },
              quuz: {
                type: 'regex',
                value: '/(.*)quux/gi',
              },
            },
            url: {
              type: 'glob',
              value: options.url,
            },
            webSocket: options.webSocket,
          },
        }

        const expectedRoute = {
          options,
          handler,
        }

        this.testRoute(options, handler, expectedEvent, expectedRoute)
      })

      context('errors', function () {
        beforeEach(function () {
          this.logs = []

          cy.on('log:added', (attrs, log) => {
            this.lastLog = log
          })
        })

        context('with invalid handler', function () {
          [false, null].forEach(function (handler) {
            const name = String(handler)

            it(`${name} fails`, function (done) {
              cy.on('fail', (err) => {
                expect(err).to.eq(this.lastLog.get('error'))
                expect(err.message).to.contain(`You passed: ${name}`)

                done()
              })

              // @ts-ignore - this should error
              cy.route2('/', handler)
            })
          })
        })

        context('with invalid StaticResponse', function () {
          [
            [
              'destroySocket set but not alone',
              {
                destroySocket: true,
                body: 'aaa',
              },
              'must be the only option',
            ],
            [
              'body set to an object',
              {
                body: {
                  a: 'b',
                },
              },
              'must be a string',
            ],
            [
              'statusCode out of range',
              {
                statusCode: -1,
              },
              'must be a number',
            ],
            [
              'headers invalid type',
              {
                headers: {
                  a: {
                    1: 2,
                  },
                },
              },
              'must be a map',
            ],
          ].forEach(function ([name, handler, expectedErr]) {
            it(`${name} fails`, function (done) {
              cy.on('fail', (err) => {
                expect(err).to.eq(this.lastLog.get('error'))
                expect(err.message).to.contain(expectedErr)
                expect(err.message).to.contain(`You passed: ${JSON.stringify(handler, null, 2)}`)

                done()
              })

              // @ts-ignore - this should error
              cy.route2('/', handler)
            })
          })
        })
      })
    })

    context('stubbing with static responses', function () {
      it('can stub a response with static body as string', function (done) {
        cy.route2({
          url: '*',
        }, 'hello world').then(() => {
          const xhr = new XMLHttpRequest

          xhr.open('GET', '/abc123')
          xhr.send()

          xhr.onload = () => {
            expect(xhr.status).to.eq(200)
            expect(xhr.responseText).to.eq('hello world')

            done()
          }
        })
      })

      it('can stub a cy.visit with static body', function () {
        cy.route2('/foo', '<html>hello cruel world</html>').visit('/foo').document().should('contain.text', 'hello cruel world')
      })

      it('can stub a response with an empty StaticResponse', function (done) {
        cy.route2('/', {}).then(() => {
          const xhr = new XMLHttpRequest

          xhr.open('GET', '/')
          xhr.send()

          xhr.onload = () => {
            expect(xhr.status).to.eq(200)
            expect(xhr.responseText).to.eq('')

            done()
          }
        })
      })

      it('can stub a response with a network error', function (done) {
        cy.route2('/', {
          destroySocket: true,
        }).then(() => {
          const xhr = new XMLHttpRequest

          xhr.open('GET', '/')
          xhr.send()

          xhr.onerror = () => {
            expect(xhr.readyState).to.eq(4)
            expect(xhr.status).to.eq(0)

            done()
          }
        })
      })
    })

    context('stubbing with dynamic response', function () {
      it('receives the original request in handler', function (done) {
        cy.route2('/def456', function (req) {
          req.reply({
            statusCode: 404,
          })

          expect(req).to.include({
            url: 'http://localhost:3500/def456',
            method: 'GET',
            httpVersion: '1.1',
          })

          done()
        }).then(function () {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', '/def456')

          xhr.send()
        })
      })
    })

    context('intercepting request', function () {
      it('receives the original request body in handler', function (done) {
        cy.route2('/aaa', function (req) {
          expect(req.body).to.eq('foo-bar-baz')

          done()
        }).then(function () {
          const xhr = new XMLHttpRequest()

          xhr.open('POST', '/aaa')

          xhr.send('foo-bar-baz')
        })
      })

      it('can modify original request body and have it passed to next handler', function (done) {
        cy.route2('/post-only', function (req, next) {
          expect(req.body).to.eq('foo-bar-baz')
          req.body = 'quuz'

          next()
        }).then(function () {
          cy.route2('/post-only', function (req, next) {
            expect(req.body).to.eq('quuz')
            req.body = 'quux'

            next()
          })
        }).then(function () {
          cy.route2('/post-only', function (req) {
            expect(req.body).to.eq('quux')

            done()
          })
        }).then(function () {
          const xhr = new XMLHttpRequest()

          xhr.open('POST', '/post-only')

          xhr.send('foo-bar-baz')
        })
      })

      it('can modify a cy.visit before it goes out', function () {
        cy.route2('/dump-headers', function (req) {
          expect(req.headers['foo']).to.eq('bar')

          req.headers['foo'] = 'quux'
        }).then(function () {
          cy.visit({
            url: '/dump-headers',
            headers: {
              'foo': 'bar',
            },
          })

          cy.get('body').should('contain.text', '"foo":"quux"')
        })
      })

      it('can modify the request URL and headers', function (done) {
        cy.route2('/does-not-exist', function (req) {
          expect(req.headers['foo']).to.eq('bar')
          req.url = 'http://localhost:3500/dump-headers'

          req.headers['foo'] = 'quux'
        }).then(function () {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', '/does-not-exist')
          xhr.setRequestHeader('foo', 'bar')
          xhr.send()

          xhr.onload = () => {
            expect(xhr.responseText).to.contain('"foo":"quux"')

            done()
          }
        })
      })

      it('can modify the request method', function (done) {
        cy.route2('/dump-method', function (req) {
          expect(req.method).to.eq('POST')

          req.method = 'PATCH'
        }).then(function () {
          const xhr = new XMLHttpRequest()

          xhr.open('POST', '/dump-method')
          xhr.send()

          xhr.onload = () => {
            expect(xhr.responseText).to.contain('request method: PATCH')

            done()
          }
        })
      })

      it('can modify the request body', function (done) {
        const body = '{"foo":"bar"}'

        cy.route2('/post-only', function (req) {
          expect(req.body).to.eq('quuz')
          req.headers['content-type'] = 'application/json'

          req.body = body
        }).then(function () {
          const xhr = new XMLHttpRequest()

          xhr.open('POST', '/post-only')
          xhr.send('quuz')

          xhr.onload = () => {
            expect(xhr.responseText).to.contain(body)

            done()
          }
        })
      })

      it('can add a body to a request that does not have one', function (done) {
        const body = '{"foo":"bar"}'

        cy.route2('/post-only', function (req) {
          expect(req.body).to.eq('')
          expect(req.method).to.eq('GET')
          req.method = 'POST'
          req.headers['content-type'] = 'application/json'

          req.body = body
        }).then(function () {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', '/post-only')
          xhr.send()

          xhr.onload = () => {
            expect(xhr.responseText).to.contain(body)

            done()
          }
        })
      })

      context('request handler chaining', function () {
        it('passes request through in order using next()', function () {
          cy.route2('/dump-method', function (req, next) {
            expect(req.method).to.eq('GET')
            req.method = 'POST'

            next()
          }).route2('/dump-method', function (req, next) {
            expect(req.method).to.eq('POST')
            req.method = 'PATCH'

            next()
          }).route2('/dump-method', function (req) {
            expect(req.method).to.eq('PATCH')

            req.reply()
          }).visit('/dump-method').contains('PATCH')
        })

        it('stops passing request through once req.reply called', function () {
          cy.route2('/dump-method', function (req, next) {
            expect(req.method).to.eq('GET')
            req.method = 'POST'

            next()
          }).route2('/dump-method', function (req) {
            expect(req.method).to.eq('POST')

            req.reply()
          }).visit('/dump-method').contains('POST')
        })
      })

      context('errors + warnings', function () {
        it('warns if req.reply is called twice in req handler', function (done) {
          cy.route2('/dump-method', function (req) {
            req.reply()

            req.reply()
          }).visit('/dump-method').then(() => {
            expect(Cypress.utils.warning).to.be.calledOnce
            .and.calledWithMatch('req.reply() was called multiple times in a request handler')

            done()
          })
        })

        it('warns if next is called twice in req handler', function (done) {
          cy.route2('/dump-method', function (req, next) {
            next()

            next()
          }).then(() => {
            const xhr = new XMLHttpRequest

            xhr.open('GET', '/dump-method')
            xhr.send()

            xhr.onload = () => {
              expect(Cypress.utils.warning).to.be.calledOnce
              .and.calledWithMatch('next() was called multiple times in a request handler')

              done()
            }
          })
        })

        it('warns if next is called after req.reply in req handler', function (done) {
          cy.route2('/dump-method', function (req, next) {
            req.reply()

            next()
          }).then(() => {
            const xhr = new XMLHttpRequest

            xhr.open('GET', '/dump-method')
            xhr.send()

            xhr.onload = () => {
              expect(Cypress.utils.warning).to.be.calledOnce
              .and.calledWithMatch('next() was called after req.reply() in a request handler')

              done()
            }
          })
        })

        it('warns if req.reply is called after next in req handler', function (done) {
          cy.route2('/dump-method', function (req, next) {
            next()

            req.reply()
          }).then(() => {
            const xhr = new XMLHttpRequest

            xhr.open('GET', '/dump-method')
            xhr.send()

            xhr.onload = () => {
              expect(Cypress.utils.warning).to.be.calledOnce
              .and.calledWithMatch('req.reply() was called after next() in a request handler')

              done()
            }
          })
        })
      })
    })

    context('intercepting response', function () {
      it('receives the original response in handler', function (done) {
        cy.route2('/json-content-type', function (req) {
          req.reply(function (res) {
            expect(res.body).to.eq('{}')

            done()
          })

          expect(req).to.include({
            url: 'http://localhost:3500/json-content-type',
          })
        }).then(function () {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', '/json-content-type')

          xhr.send()
        })
      })

      it('can intercept a large proxy response', function (done) {
        cy.route2('/1mb', (req) => {
          req.reply((res) => {
            res.send()
          })
        }).then(() => {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', '/1mb')
          xhr.send()

          xhr.onload = () => {
            // TODO: if this fails, browser totally locks up :S
            expect(xhr.responseText).to.eq('X'.repeat(1024 * 1024))

            done()
          }
        })
      })

      it('can delay a proxy response using res.delay', function (done) {
        cy.route2('/timeout', (req) => {
          req.reply((res) => {
            this.start = Date.now()

            res.delay(1000).send('delay worked')
          })
        }).then(() => {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', '/timeout')
          xhr.send()

          xhr.onload = () => {
            expect(Date.now() - this.start).to.be.closeTo(1000, 100)
            expect(xhr.responseText).to.eq('delay worked')

            done()
          }
        })
      })

      it('can \'delay\' a proxy response using setTimeout', function (done) {
        cy.route2('/timeout', (req) => {
          req.reply((res) => {
            this.start = Date.now()

            setTimeout(() => {
              res.send('setTimeout worked')
            }, 1000)
          })
        }).then(() => {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', '/timeout')
          xhr.send()

          xhr.onload = () => {
            expect(Date.now() - this.start).to.be.closeTo(1000, 100)
            expect(xhr.responseText).to.eq('setTimeout worked')

            done()
          }
        })
      })

      it('can throttle a proxy response using res.throttle', function (done) {
        cy.route2('/1mb', (req) => {
          // don't let gzip make response smaller and throw off the timing
          delete req.headers['accept-encoding']

          req.reply((res) => {
            this.start = Date.now()

            res.throttle(1024).send()
          })
        }).then(() => {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', '/1mb')
          xhr.send()

          xhr.onload = () => {
            // 1MB @ 1MB/s = ~1 second
            expect(Date.now() - this.start).to.be.closeTo(1000, 250)
            expect(xhr.responseText).to.eq('X'.repeat(1024 * 1024))

            done()
          }
        })
      })

      it('can throttle a static response using res.throttle', function (done) {
        const payload = 'A'.repeat(10 * 1024)
        const kbps = 10
        const expectedSeconds = payload.length / (1024 * kbps)

        cy.route2('/timeout', (req) => {
          req.reply((res) => {
            this.start = Date.now()

            res.throttle(kbps).send(payload)
          })
        }).then(() => {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', '/timeout')
          xhr.send()

          xhr.onload = () => {
            expect(Date.now() - this.start).to.be.closeTo(expectedSeconds * 1000, 250)
            expect(xhr.responseText).to.eq(payload)

            done()
          }
        })
      })

      it('can delay and throttle a static response', function (done) {
        const payload = 'A'.repeat(10 * 1024)
        const kbps = 20
        let expectedSeconds = payload.length / (1024 * kbps)
        const delayMs = 500

        expectedSeconds += delayMs / 1000

        cy.route2('/timeout', (req) => {
          req.reply((res) => {
            this.start = Date.now()

            res.throttle(kbps).delay(delayMs).send({
              statusCode: 200,
              body: payload,
            })
          })
        }).then(() => {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', '/timeout')
          xhr.send()

          xhr.onload = () => {
            expect(Date.now() - this.start).to.be.closeTo(expectedSeconds * 1000, 100)
            expect(xhr.responseText).to.eq(payload)

            done()
          }
        })
      })

      context('errors + warnings', function () {
        it('warns if res.send is called twice in req handler', function (done) {
          cy.route2('/dump-method', function (req) {
            req.reply(function (res) {
              res.send()

              res.send()
            })
          }).visit('/dump-method').then(() => {
            expect(Cypress.utils.warning).to.be.calledOnce
            .and.calledWithMatch('res.send() was called multiple times in a response handler')

            done()
          })
        })
      })
    })

    context('intercepting response errors', function () {
      it('sends an error object to handler if host DNE', function (done) {
        cy.route2('/should-err', function (req) {
          req.reply(function (res) {
            expect(res.error).to.include({
              code: 'ECONNREFUSED',
              port: 3333,
            })

            expect(res.url).to.eq('http://localhost:3333/should-err')

            done()
          })
        }).then(function () {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', 'http://localhost:3333/should-err')

          xhr.send()
        })
      })

      // TODO: fix once certain about API design
      it.skip('can send a successful response even if an error occurs', function (done) {
        cy.route2('/should-err', function (req) {
          req.reply(function (res) {
            // TODO: better API for this?
            expect(res.error).to.exist

            res.send({
              statusCode: 200,
              headers: {
                'access-control-allow-origin': '*',
              },
              body: 'everything is fine',
            })
          })
        }).then(function () {
          const xhr = new XMLHttpRequest()

          xhr.open('GET', 'http://localhost:3333/should-err')
          xhr.send()

          xhr.onload = () => {
            expect(xhr.responseText).to.eq('everything is fine')
            expect(xhr.status).to.eq(200)

            done()
          }
        })
      })
    })

    context('waiting and aliasing', function () {
      it('can wait on a single response using "alias"', function () {
        cy.route2('/foo')
        .as('foo.bar')
        .then(() => {
          $.get('/foo')
        })
        .wait('@foo.bar')
      })

      it('can timeout waiting on a single response using "alias"', function (done) {
        cy.on('fail', (err) => {
          expect(err.message).to.contain('No response ever occurred.')
          done()
        })

        cy.route2('/foo', _.noop)
        .as('foo.bar')
        .then(() => {
          $.get('/foo')
        })
        .wait('@foo.bar', { timeout: 100 })
      })

      it('can wait on a single response using "alias.response"', function () {
        cy.route2('/foo')
        .as('foo.bar')
        .then(() => {
          $.get('/foo')
        })
        .wait('@foo.bar.response')
      })

      it('can timeout waiting on a single response using "alias.response"', function (done) {
        cy.on('fail', (err) => {
          expect(err.message).to.contain('No response ever occurred.')
          done()
        })

        cy.route2('/foo', _.noop)
        .as('foo.bar')
        .then(() => {
          $.get('/foo')
        })
        .wait('@foo.bar.response', { timeout: 100 })
      })

      it('can wait on a single request using "alias.request"', function () {
        cy.route2('/foo')
        .as('foo.bar')
        .then(() => {
          $.get('/foo')
        })
        .wait('@foo.bar.request')
      })

      it('can timeout waiting on a single request using "alias.request"', function (done) {
        cy.on('fail', (err) => {
          expect(err.message).to.contain('No request ever occurred.')
          done()
        })

        cy.route2('/foo')
        .as('foo.bar')
        .wait('@foo.bar.request', { timeout: 100 })
      })

      it('can incrementally wait on responses', function () {
        cy.route2('/foo')
        .as('foo.bar')
        .then(() => {
          $.get('/foo')
        })
        .wait('@foo.bar')
        .then(() => {
          $.get('/foo')
        })
        .wait('@foo.bar')
      })

      it('can timeout incrementally waiting on responses', function (done) {
        cy.on('fail', (err) => {
          expect(err.message).to.contain('for the 1st response to the route')
          done()
        })

        cy.route2('/foo', _.noop)
        .as('foo.bar')
        .then(() => {
          $.get('/foo')
          $.get('/foo')
        })
        .wait('@foo.bar', { timeout: 100 })
        .wait('@foo.bar', { timeout: 100 })
      })

      it('can incrementally wait on requests', function () {
        cy.route2('/foo', (req) => {
          req.reply(_.noop) // only request will be received, no response
        })
        .as('foo.bar')
        .then(() => {
          $.get('/foo')
        })
        .wait('@foo.bar.request')
        .then(() => {
          $.get('/foo')
        })
        .wait('@foo.bar.request')
      })

      // TODO: erring
      it.skip('can timeout incrementally waiting on requests', function (done) {
        cy.on('fail', (err) => {
          expect(err.message).to.contain('for the 2nd request to the route')
          done()
        })

        cy.route2('/foo', (req) => {
          req.reply(_.noop) // only request will be received, no response
        })
        .as('foo.bar')
        .then(() => {
          $.get('/foo')
        })
        .wait('@foo.bar.request')
        .wait('@foo.bar.request', { timeout: 100 })
      })

      // TODO: the ordinals here are off
      it.skip('can wait for things that do not make sense but are technically true', function () {
        cy.route2('/foo')
        .as('foo.bar')
        .then(() => {
          $.get('/foo')
        })
        .wait('@foo.bar.1')
        .wait('@foo.bar.1') // still only asserting on the 1st response
        .wait('@foo.bar.request') // now waiting for the next request
      })

      // NOTE: was undocumented in cy.route2, may not continue to support
      context.skip('indexed aliases', function () {
        it('can wait on the 3rd request using "alias.3"', function () {
          cy.route2('/foo')
          .as('foo.bar')
          .then(() => {
            _.times(3, () => {
              $.get('/foo')
            })
          })
          .wait('@foo.bar.3')
        })

        it('can timeout waiting on the 3rd request using "alias.3"', function (done) {
          cy.on('fail', (err) => {
            expect(err.message).to.contain('No response ever occurred.')
            done()
          })

          cy.route2('/foo')
          .as('foo.bar')
          .then(() => {
            _.times(2, () => {
              $.get('/foo')
            })
          })
          .wait('@foo.bar.3', { timeout: 100 })
        })
      })

      context('errors', function () {

      })
    })

    // TODO: establish compatibility with old xhr api
    context('old xhr spec', function () {
      before(function () {
        cy.visit('/fixtures/jquery.html').then(function (win) {
          let h

          h = $(win.document.head)
          h.find('script').remove()
          this.head = h.prop('outerHTML')

          return this.body = win.document.body.outerHTML
        })
      })

      beforeEach(function () {
        let doc

        doc = cy.state('document')
        $(doc.head).empty().html(this.head)

        return $(doc.body).empty().html(this.body)
      })

      // NOTE: some of these concepts are worth ensuring tests exist for
      context.skip('#startXhrServer', function () {
        it('continues to be a defined properties', function () {
          cy.route2({
            url: /foo/,
          }).as('getFoo').window().then(function (win) {
            let xhr

            xhr = new win.XMLHttpRequest
            xhr.open('GET', '/foo')
            expect(xhr.onload).to.be.a('function')
            expect(xhr.onerror).to.be.a('function')

            expect(xhr.onreadystatechange).to.be.a('function')
          })
        })

        it('prevents infinite recursion', function () {
          let onloaded; let onreadystatechanged

          onloaded = false
          onreadystatechanged = false

          cy.route2({
            url: /foo/,
          }).as('getFoo').window().then(function (win) {
            let handlers; let wrap; let xhr

            handlers = ['onload', 'onerror', 'onreadystatechange']
            wrap = function () {
              return handlers.forEach(function (handler) {
                let bak

                bak = xhr[handler]

                return xhr[handler] = function (...args) {
                  if (_.isFunction(bak)) {
                    return bak.apply(xhr, args)
                  }
                }
              })
            }

            xhr = new win.XMLHttpRequest
            xhr.addEventListener('readystatechange', wrap, false)
            xhr.onreadystatechange = function () {
              throw new Error('NOOO')
            }

            xhr.onreadystatechange
            xhr.onreadystatechange = function () {
              return onreadystatechanged = true
            }

            xhr.open('GET', '/foo')
            xhr.onload = function () {
              throw new Error('NOOO')
            }

            xhr.onload
            xhr.onload = function () {
              return onloaded = true
            }

            xhr.send()

            return null
          }).wait('@getFoo').then(function (xhr) {
            expect(onloaded).to.be.true
            expect(onreadystatechanged).to.be.true

            expect(xhr.status).to.eq(404)
          })
        })

        it('allows multiple readystatechange calls', function () {
          let responseStatuses

          responseStatuses = 0

          cy.route2({
            url: /longtext.txt/,
          }).as('getLongText').task('create:long:file').window().then(function (win) {
            let xhr

            xhr = new win.XMLHttpRequest()
            xhr.onreadystatechange = function () {
              if (xhr.readyState === 3) {
                responseStatuses++
              }
            }

            xhr.open('GET', `/_test-output/longtext.txt?${Cypress._.random(0, 1e6)}`)
            xhr.send()

            return null
          }).wait('@getLongText').then(function (xhr) {
            expect(responseStatuses).to.be.gt(1)

            expect(xhr.status).to.eq(200)
          })
        })

        it('works with jquery too', function () {
          let failed; let onloaded

          failed = false
          onloaded = false

          cy.route2({
            url: /foo/,
          }).as('getFoo').window().then(function (win) {
            let handlers; let open; let wrap

            handlers = ['onload', 'onerror', 'onreadystatechange']
            wrap = function () {
              let xhr

              xhr = this

              return handlers.forEach(function (handler) {
                let bak

                bak = xhr[handler]

                return xhr[handler] = function (...args) {
                  if (_.isFunction(bak)) {
                    return bak.apply(xhr, args)
                  }
                }
              })
            }

            open = win.XMLHttpRequest.prototype.open
            win.XMLHttpRequest.prototype.open = function (...args) {
              this.addEventListener('readystatechange', wrap, false)

              return open.apply(this, args)
            }

            return null
          }).wait('@getFoo').then(function (xhr) {
            expect(failed).to.be.true
            expect(onloaded).to.be.true

            expect(xhr.status).to.eq(404)
          })
        })

        it('calls existing onload handlers', function () {
          let onloaded

          onloaded = false

          cy.route2({
            url: /foo/,
          }).as('getFoo').window().then(function (win) {
            let xhr

            xhr = new win.XMLHttpRequest
            xhr.onload = function () {
              return onloaded = true
            }

            xhr.open('GET', '/foo')
            xhr.send()

            return null
          }).wait('@getFoo').then(function (xhr) {
            expect(onloaded).to.be.true

            expect(xhr.status).to.eq(404)
          })
        })

        it('calls onload handlers attached after xhr#send', function () {
          let onloaded

          onloaded = false

          cy.route2({
            url: /foo/,
          }).as('getFoo').window().then(function (win) {
            let xhr

            xhr = new win.XMLHttpRequest
            xhr.open('GET', '/foo')
            xhr.send()
            xhr.onload = function () {
              return onloaded = true
            }

            return null
          }).wait('@getFoo').then(function (xhr) {
            expect(onloaded).to.be.true

            expect(xhr.status).to.eq(404)
          })
        })

        it('calls onload handlers attached after xhr#send asynchronously', function () {
          let onloaded

          onloaded = false

          cy.route2({
            url: /timeout/,
          }).as('getTimeout').window().then(function (win) {
            let xhr

            xhr = new win.XMLHttpRequest
            xhr.open('GET', '/timeout?ms=100')
            xhr.send()
            _.delay(function () {
              return xhr.onload = function () {
                return onloaded = true
              }
            }, 20)

            return null
          }).wait('@getTimeout').then(function (xhr) {
            expect(onloaded).to.be.true

            expect(xhr.status).to.eq(200)
          })
        })

        it('fallbacks even when onreadystatechange is overriden', function () {
          let onloaded; let onreadystatechanged

          onloaded = false
          onreadystatechanged = false

          cy.route2({
            url: /timeout/,
          }).as('get.timeout').window().then(function (win) {
            let xhr

            xhr = new win.XMLHttpRequest
            xhr.open('GET', '/timeout?ms=100')
            xhr.send()
            xhr.onreadystatechange = function () {
              return onreadystatechanged = true
            }

            xhr.onload = function () {
              return onloaded = true
            }

            return null
          }).wait('@get.timeout').then(function (xhr) {
            expect(onloaded).to.be.true
            expect(onreadystatechanged).to.be.true

            expect(xhr.status).to.eq(200)
          })
        })

        describe('url rewriting', function () {
          it('has a FQDN absolute-relative url', function () {
            cy.route2({
              url: /foo/,
            }).as('getFoo').window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('/foo')

              return null
            }).wait('@getFoo').then(function (xhr) {
              expect(xhr.url).to.eq('http://localhost:3500/foo')

              expect(this.open).to.be.calledWith('GET', '/foo')
            })
          })

          it('has a relative URL', function () {
            cy.route2(/foo/).as('getFoo').window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('foo')

              return null
            }).wait('@getFoo').then(function (xhr) {
              expect(xhr.url).to.eq('http://localhost:3500/fixtures/foo')

              expect(this.open).to.be.calledWith('GET', 'foo')
            })
          })

          it('resolves relative urls correctly when base tag is present', function () {
            cy.route2({
              url: /foo/,
            }).as('getFoo').window().then(function (win) {
              win.$('<base href=\'/\'>').appendTo(win.$('head'))
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('foo')

              return null
            }).wait('@getFoo').then(function (xhr) {
              expect(xhr.url).to.eq('http://localhost:3500/foo')

              expect(this.open).to.be.calledWith('GET', 'foo')
            })
          })

          it('resolves relative urls correctly when base tag is present on nested routes', function () {
            cy.route2({
              url: /foo/,
            }).as('getFoo').window().then(function (win) {
              win.$('<base href=\'/nested/route/path\'>').appendTo(win.$('head'))
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('../foo')

              return null
            }).wait('@getFoo').then(function (xhr) {
              expect(xhr.url).to.eq('http://localhost:3500/nested/foo')

              expect(this.open).to.be.calledWith('GET', '../foo')
            })
          })

          it('allows cross origin requests to go out as necessary', function () {
            cy.route2(/foo/).as('getFoo').window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('http://localhost:3501/foo')

              return null
            }).wait('@getFoo').then(function (xhr) {
              expect(xhr.url).to.eq('http://localhost:3501/foo')

              expect(this.open).to.be.calledWith('GET', 'http://localhost:3501/foo')
            })
          })

          it('rewrites FQDN url\'s for stubs', function () {
            cy.route2({
              url: /foo/,
              response: {},
            }).as('getFoo').window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('http://localhost:9999/foo')

              return null
            }).wait('@getFoo').then(function (xhr) {
              expect(xhr.url).to.eq('http://localhost:9999/foo')

              expect(this.open).to.be.calledWith('GET', '/__cypress/xhrs/http://localhost:9999/foo')
            })
          })

          it('rewrites absolute url\'s for stubs', function () {
            cy.route2(/foo/, {}).as('getFoo').window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('/foo')

              return null
            }).wait('@getFoo').then(function (xhr) {
              expect(xhr.url).to.eq('http://localhost:3500/foo')

              expect(this.open).to.be.calledWith('GET', '/__cypress/xhrs/http://localhost:3500/foo')
            })
          })

          it('rewrites 404\'s url\'s for stubs', function () {
            cy.window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')

              return new Promise(function (resolve) {
                return win.$.ajax({
                  method: 'POST',
                  url: '/foo',
                  data: JSON.stringify({
                    foo: 'bar',
                  }),
                }).fail(function () {
                  resolve()
                })
              })
            }).then(function () {
              let xhr

              xhr = cy.state('responses')[0].xhr
              expect(xhr.url).to.eq('http://localhost:3500/foo')

              expect(this.open).to.be.calledWith('POST', '/__cypress/xhrs/http://localhost:3500/foo')
            })
          })

          it('rewrites urls with nested segments', function () {
            cy.route2({
              url: /phones/,
              response: {},
            }).as('getPhones').window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('phones/phones.json')

              return null
            }).wait('@getPhones').then(function () {
              let xhr

              xhr = cy.state('responses')[0].xhr
              expect(xhr.url).to.eq('http://localhost:3500/fixtures/phones/phones.json')

              expect(this.open).to.be.calledWith('GET', '/__cypress/xhrs/http://localhost:3500/fixtures/phones/phones.json')
            })
          })

          it('does not rewrite CORS', function () {
            cy.window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')

              return new Promise(function (resolve) {
                return win.$.get('http://www.google.com/phones/phones.json').fail(function () {
                  resolve()
                })
              })
            }).then(function () {
              let xhr

              xhr = cy.state('requests')[0].xhr
              expect(xhr.url).to.eq('http://www.google.com/phones/phones.json')

              expect(this.open).to.be.calledWith('GET', 'http://www.google.com/phones/phones.json')
            })
          })

          it('can stub real CORS requests too', function () {
            cy.route2({
              url: /phones/,
              response: {},
            }).as('getPhones').window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('http://www.google.com/phones/phones.json')

              return null
            }).wait('@getPhones').then(function () {
              let xhr

              xhr = cy.state('responses')[0].xhr
              expect(xhr.url).to.eq('http://www.google.com/phones/phones.json')

              expect(this.open).to.be.calledWith('GET', '/__cypress/xhrs/http://www.google.com/phones/phones.json')
            })
          })

          it('can stub CORS string routes', function () {
            cy.route2('http://localhost:3501/fixtures/app.json').as('getPhones').window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('http://localhost:3501/fixtures/app.json')

              return null
            }).wait('@getPhones').then(function () {
              let xhr

              xhr = cy.state('responses')[0].xhr
              expect(xhr.url).to.eq('http://localhost:3501/fixtures/app.json')

              expect(this.open).to.be.calledWith('GET', 'http://localhost:3501/fixtures/app.json')
            })
          })

          it('sets display correctly when there is no remoteOrigin', function () {
            // this is an example of having cypress act as your webserver
            // when the remoteHost is <root>
            cy.route2({
              url: /foo/,
              response: {},
            }).as('getFoo').window().then(function (win) {
              // trick cypress into thinking the remoteOrigin is location:9999
              // @ts-ignore
              cy.stub(cy, 'getRemoteLocation').withArgs('origin').returns('')
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('/foo')

              return null
            }).wait('@getFoo').then(function (xhr) {
              expect(xhr.url).to.eq('http://localhost:3500/foo')

              expect(this.open).to.be.calledWith('GET', '/__cypress/xhrs/http://localhost:3500/foo')
            })
          })

          it('decodes proxy urls', function () {
            cy.route2({
              url: /users/,
              response: {},
            }).as('getUsers').window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('/users?q=(id eq 123)')

              return null
            }).wait('@getUsers').then(function () {
              let url; let xhr

              xhr = cy.state('responses')[0].xhr
              expect(xhr.url).to.eq('http://localhost:3500/users?q=(id eq 123)')
              url = encodeURI('users?q=(id eq 123)')

              expect(this.open).to.be.calledWith('GET', `/__cypress/xhrs/http://localhost:3500/${url}`)
            })
          })

          it('decodes proxy urls #2', function () {
            cy.route2(/accounts/, {}).as('getAccounts').window().then(function (win) {
              this.open = cy.spy(cy.state('server').options, 'onOpen')
              win.$.get('/accounts?page=1&%24filter=(rowStatus+eq+1)&%24orderby=name+asc&includeOpenFoldersCount=true&includeStatusCount=true')

              return null
            }).wait('@getAccounts').then(function () {
              let url; let xhr

              xhr = cy.state('responses')[0].xhr
              expect(xhr.url).to.eq('http://localhost:3500/accounts?page=1&$filter=(rowStatus+eq+1)&$orderby=name+asc&includeOpenFoldersCount=true&includeStatusCount=true')
              url = 'accounts?page=1&%24filter=(rowStatus+eq+1)&%24orderby=name+asc&includeOpenFoldersCount=true&includeStatusCount=true'

              expect(this.open).to.be.calledWith('GET', `/__cypress/xhrs/http://localhost:3500/${url}`)
            })
          })
        })

        describe('#onResponse', function () {
          // NOTE: not ported from XHR-based stubbing - XHR-specific
          it('calls onResponse callback with cy context + proxy xhr', function (done) {
            cy.route2({
              url: /foo/,
              response: {
                foo: 'bar',
              },
              onResponse (xhr) {
                expect(this).to.eq(cy)
                // @ts-ignore
                expect(xhr.responseBody).to.deep.eq({
                  foo: 'bar',
                })

                done()
              },
            }).window().then(function (win) {
              win.$.get('/foo')

              return null
            })
          })
        })

        describe('#onAbort', function () {
          it('calls onAbort callback with cy context + proxy xhr', function (done) {
            cy.route2({
              url: /foo/,
              response: {},
              onAbort (xhr) {
                expect(this).to.eq(cy)
                expect(xhr.aborted).to.be.true

                done()
              },
            }).window().then(function (win) {
              let xhr

              xhr = new win.XMLHttpRequest
              xhr.open('GET', '/foo')
              xhr.send()
              xhr.abort()

              return null
            })
          })
        })

        describe('request parsing', function () {
          // NOTE: not ported from XHR-based stubbing - XHR-specific
          it.skip('adds parses requestBody into JSON', function (done) {
            cy.route2({
              method: 'POST',
              url: /foo/,
              response: {},
              onRequest (xhr) {
                expect(this).to.eq(cy)
                // @ts-ignore
                expect(xhr.requestBody).to.deep.eq({
                  foo: 'bar',
                })

                done()
              },
            }).window().then(function (win) {
              win.$.ajax({
                type: 'POST',
                url: '/foo',
                data: JSON.stringify({
                  foo: 'bar',
                }),
                dataType: 'json',
              })

              return null
            })
          })

          // https://github.com/cypress-io/cypress/issues/65
          it('provides the correct requestBody on multiple requests', function () {
            let post

            post = function (win, obj) {
              win.$.ajax({
                type: 'POST',
                url: '/foo',
                data: JSON.stringify(obj),
                dataType: 'json',
              })

              return null
            }

            cy.route2('POST', /foo/, {}).as('getFoo').window().then(function (win) {
              return post(win, {
                foo: 'bar1',
              })
            }).wait('@getFoo').its('requestBody').should('deep.eq', {
              foo: 'bar1',
            }).window().then(function (win) {
              return post(win, {
                foo: 'bar2',
              })
            }).wait('@getFoo').its('requestBody').should('deep.eq', {
              foo: 'bar2',
            })
          })

          it('handles arraybuffer', function () {
            cy.route2('GET', /buffer/).as('getBuffer').window().then(function (win) {
              let xhr

              xhr = new win.XMLHttpRequest
              xhr.responseType = 'arraybuffer'
              xhr.open('GET', '/buffer')
              xhr.send()

              return null
            }).wait('@getBuffer').then(function (xhr) {
              expect(xhr.responseBody.toString()).to.eq('[object ArrayBuffer]')
            })
          })

          it('handles xml', function () {
            cy.route2('GET', /xml/).as('getXML').window().then(function (win) {
              let xhr

              xhr = new win.XMLHttpRequest
              xhr.open('GET', '/xml')
              xhr.send()

              return null
            }).wait('@getXML').its('responseBody').should('eq', '<foo>bar</foo>')
          })
        })

        describe('issue #84', function () {
          it('does not incorrectly match options', function () {
            cy.route2({
              method: 'GET',
              url: /answers/,
              status: 503,
              response: {},
            }).route2(/forms/, []).as('getForm').window().then(function (win) {
              win.$.getJSON('/forms')

              return null
            }).wait('@getForm').its('status').should('eq', 200)
          })
        })

        describe('#issue #85', function () {
          it('correctly returns the right XHR alias', function () {
            cy.route2({
              method: 'POST',
              url: /foo/,
              response: {},
            }).as('getFoo').route2(/folders/, {
              foo: 'bar',
            }).as('getFolders').window().then(function (win) {
              win.$.getJSON('/folders')
              win.$.post('/foo', {})

              return null
            }).wait('@getFolders').wait('@getFoo').route2(/folders/, {
              foo: 'baz',
            }).as('getFoldersWithSearch').window().then(function (win) {
              win.$.getJSON('/folders/123/activities?foo=bar')

              return null
            }).wait('@getFoldersWithSearch').its('url').should('contain', '?foo=bar')
          })
        })

        describe('.log', function () {
          beforeEach(function () {
            this.logs = []
            cy.on('log:added', (attrs, log) => {
              if (attrs.name === 'xhr') {
                this.lastLog = log

                this.logs.push(log)
              }
            })

            return null
          })

          context('requests', function () {
            it('immediately logs xhr obj', function () {
              cy.route2(/foo/, {}).as('getFoo').window().then(function (win) {
                win.$.get('foo')

                return null
              }).then(function () {
                let lastLog; let snapshots

                lastLog = this.lastLog
                expect(lastLog.pick('name', 'displayName', 'event', 'alias', 'aliasType', 'state')).to.deep.eq({
                  name: 'xhr',
                  displayName: 'xhr stub',
                  event: true,
                  alias: 'getFoo',
                  aliasType: 'route',
                  state: 'pending',
                })

                snapshots = lastLog.get('snapshots')
                expect(snapshots.length).to.eq(1)
                expect(snapshots[0].name).to.eq('request')

                expect(snapshots[0].body).to.be.an('object')
              })
            })

            it('does not end xhr requests when the associated command ends', function () {
              let logs

              logs = null

              cy.route2({
                url: /foo/,
                response: {},
              }).as('getFoo').window().then(function (w) {
                w.$.getJSON('foo')
                w.$.getJSON('foo')
                w.$.getJSON('foo')

                return null
              }).then(function () {
                let cmd

                cmd = cy.queue.find({
                  name: 'window',
                })

                logs = cmd.get('next').get('logs')
                expect(logs.length).to.eq(3)

                return _.each(logs, function (log) {
                  expect(log.get('name')).to.eq('xhr')

                  expect(log.get('end')).not.to.be.true
                })
              }).wait(['@getFoo', '@getFoo', '@getFoo']).then(function () {
                return _.each(logs, function (log) {
                  expect(log.get('name')).to.eq('xhr')

                  expect(log.get('ended')).to.be.true
                })
              })
            })

            it('updates log immediately whenever an xhr is aborted', function () {
              let xhrs

              xhrs = null

              cy.route2({
                url: /foo/,
                response: {},
              }).as('getFoo').window().then(function (win) {
                let xhr1

                xhr1 = win.$.getJSON('foo1')
                xhr1.abort()

                return null
              }).then(function () {
                xhrs = cy.queue.logs({
                  name: 'xhr',
                })

                expect(xhrs[0].get('state')).to.eq('failed')
                expect(xhrs[0].get('error').name).to.eq('AbortError')
                expect(xhrs[0].get('snapshots').length).to.eq(2)
                expect(xhrs[0].get('snapshots')[0].name).to.eq('request')
                expect(xhrs[0].get('snapshots')[0].body).to.be.a('object')
                expect(xhrs[0].get('snapshots')[1].name).to.eq('aborted')
                expect(xhrs[0].get('snapshots')[1].body).to.be.a('object')
                expect(cy.state('requests').length).to.eq(2)

                // the abort should have set its response
                expect(cy.state('responses').length).to.eq(1)
              }).wait(['@getFoo', '@getFoo']).then(function () {
                // should not re-snapshot after the response
                expect(xhrs[0].get('snapshots').length).to.eq(2)
              })
            })

            it('can access requestHeaders', function () {
              cy.route2(/foo/, {}).as('getFoo').window().then(function (win) {
                win.$.ajax({
                  method: 'GET',
                  url: '/foo',
                  headers: {
                    'x-token': '123',
                  },
                })

                return null
              }).wait('@getFoo').its('requestHeaders').should('have.property', 'x-token', '123')
            })
          })

          return context('responses', function () {
            beforeEach(function () {
              cy.route2(/foo/, {}).as('getFoo').window().then(function (win) {
                win.$.get('foo_bar')

                return null
              }).wait('@getFoo')
            })

            it('logs obj', function () {
              let lastLog; let obj

              obj = {
                name: 'xhr',
                displayName: 'xhr stub',
                event: true,
                message: '',
                type: 'parent',
                aliasType: 'route',
                referencesAlias: void 0,
                alias: 'getFoo',
              }

              lastLog = this.lastLog

              return _.each(obj, (value, key) => {
                expect(lastLog.get(key)).to.deep.eq(value, `expected key: ${key} to eq value: ${value}`)
              })
            })

            it('ends', function () {
              let lastLog

              lastLog = this.lastLog

              expect(lastLog.get('state')).to.eq('passed')
            })

            it('snapshots again', function () {
              let lastLog

              lastLog = this.lastLog
              expect(lastLog.get('snapshots').length).to.eq(2)
              expect(lastLog.get('snapshots')[0].name).to.eq('request')
              expect(lastLog.get('snapshots')[0].body).to.be.an('object')
              expect(lastLog.get('snapshots')[1].name).to.eq('response')

              expect(lastLog.get('snapshots')[1].body).to.be.an('object')
            })
          })
        })

        describe('errors', function () {
          beforeEach(function () {
            Cypress.config('defaultCommandTimeout', 200)
            this.logs = []
            cy.on('log:added', (attrs, log) => {
              if (attrs.name === 'xhr') {
                this.lastLog = log

                this.logs.push(log)
              }
            })

            return null
          })

          it('sets err on log when caused by code errors', function (done) {
            let uncaughtException

            uncaughtException = cy.stub().returns(true)
            cy.on('uncaught:exception', uncaughtException)
            cy.on('fail', () => {
              let lastLog

              lastLog = this.lastLog
              expect(this.logs.length).to.eq(1)
              expect(lastLog.get('name')).to.eq('xhr')
              expect(lastLog.get('error').message).contain('foo is not defined')
              // since this is AUT code, we should allow error to be caught in 'uncaught:exception' hook
              // https://github.com/cypress-io/cypress/issues/987
              expect(uncaughtException).calledOnce

              done()
            })

            cy.window().then(function (win) {
              return new Promise(function () {
                return win.$.get('http://www.google.com/foo.json').fail(function () {
                  // @ts-ignore - should error
                  // eslint-disable-next-line no-undef
                  return foo.bar()
                })
              })
            })
          })

          it('causes errors caused by onreadystatechange callback function', function (done) {
            let e

            e = new Error('onreadystatechange caused this error')
            cy.on('fail', (err) => {
              let lastLog

              lastLog = this.lastLog
              expect(this.logs.length).to.eq(1)
              expect(lastLog.get('name')).to.eq('xhr')
              expect(lastLog.get('error')).to.eq(err)
              expect(err).to.eq(e)

              done()
            })

            cy.window().then(function (win) {
              return new Promise(function () {
                let xhr

                xhr = new win.XMLHttpRequest
                xhr.open('GET', '/foo')
                xhr.onreadystatechange = function () {
                  throw e
                }

                return xhr.send()
              })
            })
          })
        })
      })

      context('#route2', function () {
        it('can use regular strings as response', function () {
          cy.route2('/foo', 'foo bar baz').as('getFoo').window().then(function (win) {
            win.$.get('/foo')

            return null
          }).wait('@getFoo').then(function (res) {
            // TODO: need to define user-accessible shape
            // expect(xhr.responseBody).to.eq('foo bar baz')
          })
        })

        it('can stub requests with uncommon HTTP methods', function () {
          cy.route2('PROPFIND', '/foo', 'foo bar baz').as('getFoo').window().then(function (win) {
            win.$.ajax({
              url: '/foo',
              method: 'PROPFIND',
            })

            return null
          }).wait('@getFoo').then(function (res) {
            // TODO: need to define user-accessible shape
            // expect(xhr.responseBody).to.eq('foo bar baz')
          })
        })

        // TODO: implement warning in cy.route2 if appropriate
        // https://github.com/cypress-io/cypress/issues/2372
        it.skip('warns if a percent-encoded URL is used', function () {
          cy.route2('GET', '/foo%25bar').then(function () {
            expect(Cypress.utils.warning).to.be.calledWith('A URL with percent-encoded characters was passed to cy.route2(), but cy.route2() expects a decoded URL.\n\nDid you mean to pass "/foo%bar"?')
          })
        })

        // NOTE: see todo on 'warns if a percent-encoded URL is used'
        it.skip('does not warn if an invalid percent-encoded URL is used', function () {
          cy.route2('GET', 'http://example.com/%E0%A4%A').then(function () {
            expect(Cypress.utils.warning).to.not.be.called
          })
        })

        describe('request response alias', function () {
          it('matches xhrs with lowercase methods', function () {
            cy.route2(/foo/, {}).as('getFoo').window().then(function (win) {
              let xhr

              xhr = new win.XMLHttpRequest
              xhr.open('get', '/foo')

              return xhr.send()
            }).wait('@getFoo')
          })

          it('can pass an alias reference to route', function () {
            cy.noop({
              foo: 'bar',
            }).as('foo').route2(/foo/, '@foo').as('getFoo').window().then(function (win) {
              win.$.getJSON('foo')

              return null
            }).wait('@getFoo').then(function (xhr) {
              // TODO: need to decide body shape
              // expect(xhr.responseBody).to.deep.eq({
              //   foo: 'bar',
              // })

              // expect(xhr.responseBody).to.deep.eq(this.foo)
            })
          })

          it('can alias a route without stubbing it', function () {
            cy.route2(/fixtures\/app/).as('getFoo').window().then(function (win) {
              win.$.get('/fixtures/app.json')

              return null
            }).wait('@getFoo').then(function (xhr) {
              let log

              log = cy.queue.logs({
                displayName: 'stubbed route',
              })[0]

              expect(log.get('alias')).to.eq('getFoo')

              // TODO: need to determine shape
              // expect(xhr.responseBody).to.deep.eq({
              //   some: 'json',
              //   foo: {
              //     bar: 'baz',
              //   },
              // })
            })
          })
        })

        describe('response fixtures', function () {
          it('works if the JSON file has an object', function () {
            cy.route2({
              method: 'POST',
              url: '/test-xhr',
            }, {
              fixture: 'valid.json',
            }).visit('/fixtures/xhr-triggered.html').get('#trigger-xhr').click()

            cy.contains('#result', '{"foo":1,"bar":{"baz":"cypress"}}').should('be.visible')
          })

          it('works with content-type override', function () {
            cy.route2({
              method: 'POST',
              url: '/test-xhr',
            }, {
              headers: {
                'content-type': 'text/plain',
              },
              fixture: 'valid.json',
            }).visit('/fixtures/xhr-triggered.html').get('#trigger-xhr').click()

            cy.contains('#result', '"{\\"foo\\":1,\\"bar\\":{\\"baz\\":\\"cypress\\"}}"').should('be.visible')
          })

          it('works if the JSON file has null content', function () {
            cy.route2({
              method: 'POST',
              url: '/test-xhr',
            }, {
              fixture: 'null.json',
            }).visit('/fixtures/xhr-triggered.html').get('#trigger-xhr').click()

            cy.contains('#result', '""').should('be.visible')
          })
        })

        describe('errors', function () {
          beforeEach(function () {
            Cypress.config('defaultCommandTimeout', 500)
            this.logs = []
            cy.on('log:added', (attrs, log) => {
              this.lastLog = log

              this.logs.push(log)
            })

            return null
          })

          it('url must be a string or regexp', function (done) {
            cy.on('fail', function (err) {
              expect(err.message).to.include('`url` must be a string or a regular expression')

              done()
            })

            // @ts-ignore: should fail
            cy.route2({
              url: {},
            })
          })

          // TODO: not currently implemented
          it.skip('fails when method is invalid', function (done) {
            cy.on('fail', function (err) {
              expect(err.message).to.include('cy.route2() was called with an invalid method: \'POSTS\'.')

              done()
            })

            cy.route2('posts', '/foo', {})
          })

          it('requires a url when given a response', function (done) {
            cy.on('fail', function (err) {
              expect(err.message).to.include('The RouteMatcher does not contain any keys. You must pass something to match on.')

              done()
            })

            cy.route2({})
          })

          it('requires arguments', function (done) {
            cy.on('fail', function (err) {
              expect(err.message).to.include('An invalid RouteMatcher was supplied to `cy.route2()`. The RouteMatcher does not contain any keys. You must pass something to match on.')

              done()
            })

            // @ts-ignore - should fail
            cy.route2()
          })

          // TODO: using aliases as responses not yet implemented
          // it('explodes if response alias cannot be found', function (done) {
          //   cy.on('fail', (err) => {
          //     let lastLog

          //     lastLog = this.lastLog
          //     expect(this.logs.length).to.eq(2)
          //     expect(err.message).to.eq('cy.route2() could not find a registered alias for: \'@bar\'.\nAvailable aliases are: \'foo\'.')
          //     expect(lastLog.get('name')).to.eq('route')
          //     expect(lastLog.get('error')).to.eq(err)
          //     expect(lastLog.get('message')).to.eq('/foo/, @bar')

          //     done()
          //   })

          //   cy.wrap({
          //     foo: 'bar',
          //   }).as('foo').route2(/foo/, '@bar')
          // })
        })

        describe('.log', function () {
          beforeEach(function () {
            this.logs = []
            cy.on('log:added', (attrs, log) => {
              if (attrs.instrument === 'route') {
                this.lastLog = log

                this.logs.push(log)
              }
            })

            return null
          })

          it('has name of route', function () {
            cy.route2('/foo', {}).then(function () {
              let lastLog

              lastLog = this.lastLog

              expect(lastLog.get('name')).to.eq('route')
            })
          })

          it('uses the wildcard URL', function () {
            cy.route2('*', {}).then(function () {
              let lastLog

              lastLog = this.lastLog

              expect(lastLog.get('url')).to.eq('*')
            })
          })

          // TODO: implement log niceties
          it.skip('#consoleProps', function () {
            cy.route2('*', {
              foo: 'bar',
            }).as('foo').then(function () {
              expect(this.lastLog.invoke('consoleProps')).to.deep.eq({
                Command: 'route',
                Method: 'GET',
                URL: '*',
                Status: 200,
                Response: {
                  foo: 'bar',
                },
                Alias: 'foo',
              })
            })
          })

          // Responded: 1 time
          // "-------": ""
          // Responses: []
          describe('numResponses', function () {
            it('is initially 0', function () {
              cy.route2(/foo/, {}).then(() => {
                let lastLog

                lastLog = this.lastLog

                expect(lastLog.get('numResponses')).to.eq(0)
              })
            })

            it('is incremented to 2', function () {
              cy.route2(/foo/, {}).window().then(function (win) {
                return win.$.get('/foo')
              }).then(function () {
                expect(this.lastLog.get('numResponses')).to.eq(1)
              })
            })

            it('is incremented for each matching request', function () {
              cy.route2(/foo/, {}).window().then(function (win) {
                return Promise.all([win.$.get('/foo'), win.$.get('/foo'), win.$.get('/foo')])
              }).then(function () {
                expect(this.lastLog.get('numResponses')).to.eq(3)
              })
            })
          })
        })
      })

      // TODO: implement log niceties
      context.skip('consoleProps logs', function () {
        beforeEach(function () {
          this.logs = []
          cy.on('log:added', (attrs, log) => {
            if (attrs.name === 'xhr') {
              this.lastLog = log

              this.logs.push(log)
            }
          })

          return null
        })

        describe('when stubbed', function () {
          it('says Stubbed: Yes', function () {
            cy.route2(/foo/, {}).as('getFoo').window().then(function (win) {
              return new Promise(function (resolve) {
                return win.$.get('/foo').done(resolve)
              })
            }).then(function () {
              expect(this.lastLog.invoke('consoleProps').Stubbed).to.eq('Yes')
            })
          })
        })

        describe('zero configuration / zero routes', function () {
          beforeEach(function () {
            cy.window().then(function (win) {
              return new Promise(function (resolve) {
                return win.$.ajax({
                  method: 'POST',
                  url: '/foo',
                  data: JSON.stringify({
                    foo: 'bar',
                  }),
                }).fail(function () {
                  resolve()
                })
              })
            })
          })

          it('calculates duration', function () {
            cy.then(function () {
              let consoleProps

              consoleProps = this.lastLog.invoke('consoleProps')
              expect(consoleProps.Duration).to.be.a('number')
              expect(consoleProps.Duration).to.be.gt(1)

              expect(consoleProps.Duration).to.be.lt(1000)
            })
          })

          it('sends back regular 404', function () {
            cy.then(function () {
              let consoleProps; let xhr

              xhr = cy.state('responses')[0].xhr
              consoleProps = _.pick(this.lastLog.invoke('consoleProps'), 'Method', 'Status', 'URL', 'XHR')

              expect(consoleProps).to.deep.eq({
                Method: 'POST',
                Status: '404 (Not Found)',
                URL: 'http://localhost:3500/foo',
                XHR: xhr.xhr,
              })
            })
          })

          it('says Stubbed: Yes when sent 404 back', function () {
            expect(this.lastLog.invoke('consoleProps').Stubbed).to.eq('Yes')
          })
        })

        describe('whitelisting', function () {
          it('does not send back 404s on whitelisted routes', function () {
            cy.window().then(function (win) {
              return win.$.get('/fixtures/app.js')
            }).then(function (resp) {
              expect(resp).to.eq('{ \'bar\' }\n')
            })
          })
        })

        describe('{force404: false}', function () {
          beforeEach(function () {
            cy.window().then(function (win) {
              return win.$.getJSON('/fixtures/app.json')
            })
          })

          it('says Stubbed: No when request isnt forced 404', function () {
            expect(this.lastLog.invoke('consoleProps').Stubbed).to.eq('No')
          })

          it('logs request + response headers', function () {
            cy.then(function () {
              let consoleProps

              consoleProps = this.lastLog.invoke('consoleProps')
              expect(consoleProps.Request.headers).to.be.an('object')

              expect(consoleProps.Response.headers).to.be.an('object')
            })
          })

          it('logs Method, Status, URL, and XHR', function () {
            cy.then(function () {
              let consoleProps; let xhr

              xhr = cy.state('responses')[0].xhr
              consoleProps = _.pick(this.lastLog.invoke('consoleProps'), 'Method', 'Status', 'URL', 'XHR')

              expect(consoleProps).to.deep.eq({
                Method: 'GET',
                URL: 'http://localhost:3500/fixtures/app.json',
                Status: '200 (OK)',
                XHR: xhr.xhr,
              })
            })
          })

          it('logs response', function () {
            cy.then(function () {
              let consoleProps

              consoleProps = this.lastLog.invoke('consoleProps')

              expect(consoleProps.Response.body).to.deep.eq({
                some: 'json',
                foo: {
                  bar: 'baz',
                },
              })
            })
          })

          it('sets groups Initiator', function () {
            cy.then(function () {
              let consoleProps; let group

              consoleProps = this.lastLog.invoke('consoleProps')
              group = consoleProps.groups()[0]
              expect(group.name).to.eq('Initiator')
              expect(group.label).to.be.false
              expect(group.items[0]).to.be.a('string')

              expect(group.items[0].split('\n').length).to.gt(1)
            })
          })
        })
      })

      context('renderProps', function () {
        beforeEach(function () {
          this.logs = []
          cy.on('log:added', (attrs, log) => {
            if (attrs.name === 'xhr') {
              this.lastLog = log

              this.logs.push(log)
            }
          })

          return null
        })

        describe('in any case', function () {
          beforeEach(function () {
            cy.route2(/foo/, {}).window().then(function (win) {
              return new Promise(function (resolve) {
                return win.$.get('/foo').done(resolve)
              })
            })
          })

          // TODO: implement log niceties
          it.skip('sends correct message', function () {
            cy.then(function () {
              expect(this.lastLog.invoke('renderProps').message).to.equal('GET 200 /foo')
            })
          })
        })

        describe('when response is successful', function () {
          beforeEach(function () {
            cy.route2(/foo/, {}).window().then(function (win) {
              return new Promise(function (resolve) {
                return win.$.get('/foo').done(resolve)
              })
            })
          })

          // TODO: this is now flaky
          it.skip('sends correct indicator', function () {
            cy.then(function () {
              expect(this.lastLog.invoke('renderProps').indicator).to.equal('successful')
            })
          })
        })

        describe('when response is pending', function () {
          beforeEach(function () {
            cy.route2({
              url: '/foo',
              response: {},
            }).window().then(function (win) {
              win.$.get('/foo')

              return null
            })
          })

          // FAILING
          it('sends correct message', function () {
            expect(this.lastLog.invoke('renderProps').message).to.equal('GET --- /foo')
          })

          it('sends correct indicator', function () {
            expect(this.lastLog.invoke('renderProps').indicator).to.equal('pending')
          })
        })

        describe('when response is outside 200 range', function () {
          beforeEach(function () {
            cy.route2({
              url: '/foo',
              status: 500,
              response: {},
            }).window().then(function (win) {
              return new Promise(function (resolve) {
                return win.$.get('/foo').fail(function () {
                  resolve()
                })
              })
            })
          })

          // TODO: determine what this should do
          it.skip('sends correct indicator', function () {
            cy.then(function () {
              expect(this.lastLog.invoke('renderProps').indicator).to.equal('bad')
            })
          })
        })
      })

      context('abort', function () {
        let xhrs

        xhrs = []
        beforeEach(function () {
          cy.visit('/fixtures/jquery.html')
        })

        it('does not abort xhr\'s between tests', function () {
          cy.window().then(function (win) {
            return _.times(2, function () {
              let xhr

              xhr = new win.XMLHttpRequest
              xhr.open('GET', '/timeout?ms=100')
              xhr.send()

              return xhrs.push(xhr)
            })
          })
        })

        it('has not aborted the xhrs', function () {
          return _.each(xhrs, function (xhr) {
            expect(xhr.aborted).not.to.be.false
          })
        })

        it('aborts xhrs that haven\'t been sent', function () {
          cy.window().then(function (win) {
            let xhr

            xhr = new win.XMLHttpRequest()
            xhr.open('GET', '/timeout?ms=0')
            xhr.abort()

            expect(xhr.aborted).to.be.true
          })
        })

        it('aborts xhrs currently in flight', function () {
          let log

          log = null
          cy.on('log:changed', (attrs, l) => {
            if (attrs.name === 'xhr') {
              if (!log) {
                log = l
              }
            }
          })

          cy.window().then(function (win) {
            let xhr

            xhr = new win.XMLHttpRequest()
            xhr.open('GET', '/timeout?ms=999')
            xhr.send()
            xhr.abort()

            cy.wrap(null).should(function () {
              expect(log.get('state')).to.eq('failed')
              expect(log.invoke('renderProps')).to.deep.eq({
                message: 'GET (aborted) /timeout?ms=999',
                indicator: 'aborted',
              })

              expect(xhr.aborted).to.be.true
            })
          })
        })

        // https://github.com/cypress-io/cypress/issues/3008
        it('aborts xhrs even when responseType  not \'\' or \'text\'', function () {
          let log

          log = null
          cy.on('log:changed', (attrs, l) => {
            if (attrs.name === 'xhr') {
              if (!log) {
                log = l
              }
            }
          })

          cy.window().then(function (win) {
            let xhr

            xhr = new win.XMLHttpRequest()
            xhr.responseType = 'arraybuffer'
            xhr.open('GET', '/timeout?ms=1000')
            xhr.send()
            xhr.abort()

            cy.wrap(null).should(function () {
              expect(log.get('state')).to.eq('failed')

              expect(xhr.aborted).to.be.true
            })
          })
        })

        // https://github.com/cypress-io/cypress/issues/1652
        it('does not set aborted on XHR\'s that have completed by have had .abort() called', function () {
          let log

          log = null
          cy.on('log:changed', (attrs, l) => {
            if (attrs.name === 'xhr') {
              if (!log) {
                log = l
              }
            }
          })

          cy.window().then(function (win) {
            return new Promise(function (resolve) {
              let xhr

              xhr = new win.XMLHttpRequest()
              xhr.open('GET', '/timeout?ms=0')
              xhr.onload = function () {
                xhr.abort()
                xhr.foo = 'bar'

                resolve(xhr)
              }

              return xhr.send()
            })
          }).then(function (xhr: any) {
            cy.wrap(null).should(function () {
              // ensure this is set to prevent accidental
              // race conditions down the road if something
              // goes wrong
              expect(xhr.foo).to.eq('bar')
              expect(xhr.aborted).not.to.be.true

              expect(log.get('state')).to.eq('passed')
            })
          })
        })
      })

      context('Cypress.on(window:before:load)', function () {
        it('reapplies server + route automatically before window:load', function () {
          // this tests that the server + routes are automatically reapplied
          // after the 2nd visit - which is an example of the remote iframe
          // causing an onBeforeLoad event
          cy.route2(/foo/, {
            body: JSON.stringify({ foo: 'bar' }),
            headers: {
              'content-type': 'application/json',
            },
          }).as('getFoo').visit('http://localhost:3500/fixtures/jquery.html').window().then(function (win) {
            return new Promise(function (resolve) {
              let xhr

              xhr = new win.XMLHttpRequest
              xhr.open('GET', '/foo')
              xhr.send()

              return xhr.onload = resolve
            })
          }).wait('@getFoo').its('req.url').should('include', '/foo').visit('http://localhost:3500/fixtures/generic.html').window().then(function (win) {
            return new Promise(function (resolve) {
              let xhr

              xhr = new win.XMLHttpRequest
              xhr.open('GET', '/foo')
              xhr.send()

              return xhr.onload = resolve
            })
          }).wait('@getFoo').its('req.url').should('include', '/foo')
        })

        it('reapplies server + route automatically during page transitions', function () {
          // this tests that the server + routes are automatically reapplied
          // after the 2nd visit - which is an example of the remote iframe
          // causing an onBeforeLoad event
          cy.route2(/foo/, {
            body: JSON.stringify({ foo: 'bar' }),
            headers: {
              'content-type': 'application/json',
            },
          }).as('getFoo').visit('http://localhost:3500/fixtures/jquery.html').window().then(function (win) {
            let $a; let url

            url = 'http://localhost:3500/fixtures/generic.html'
            $a = win.$(`<a href='${url}'>jquery</a>`).appendTo(win.document.body)

            // synchronous beforeunload
            return $a.get(0).click()
          }).url().should('include', '/generic.html').window().then(function (win) {
            return new Promise(function (resolve) {
              let xhr

              xhr = new win.XMLHttpRequest
              xhr.open('GET', '/foo')
              xhr.send()

              return xhr.onload = resolve
            })
          }).wait('@getFoo').its('req.url').should('include', '/foo')
        })
      })
    })
  })
})
