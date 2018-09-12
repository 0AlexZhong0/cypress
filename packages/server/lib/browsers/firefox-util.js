const _ = require('lodash')
const Marionette = require('marionette-client')
const Exception = require('marionette-client/lib/marionette/error')
const Command = require('marionette-client/lib/marionette/message.js').Command
const Promise = require('bluebird')

const promisify = (fn) => (...args) => {
  return new Promise((resolve, reject) => {
    fn(...args, (data) => {
      if ('error' in data) {
        reject(new Exception(data))
      } else {
        resolve(data)
      }
    })
  })
}

const driver = new Marionette.Drivers.Tcp({})

const connect = Promise.promisify(driver.connect.bind(driver))
const driverSend = promisify(driver.send.bind(driver))

const send = (data) => {
  return driverSend(new Command(data))
}

module.exports = {
  send,

  setup (extensions, url) {
    return connect()
    .then(() => {
      return send({
        name: 'WebDriver:NewSession',
        parameters: { acceptInsecureCerts: true },
      })
    })
    .then(({ sessionId }) => {
      return Promise.all(_.map(extensions, (path) => {
        return send({
          name: 'Addon:Install',
          sessionId,
          parameters: { path, temporary: true },
        })
      }))
      .then(() => {
        return send({
          name: 'WebDriver:Navigate',
          sessionId,
          parameters: { url },
        })
      })
      .return({ sessionId })
    })
  },
}

