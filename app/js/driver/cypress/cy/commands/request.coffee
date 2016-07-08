$Cypress.register "Request", (Cypress, _, $) ->

  isOkStatusCodeRe   = /^2/
  validHttpMethodsRe = /^(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)$/

  optionalOpts = "body auth headers json".split(" ")

  defaults = {
    log: true
    body: null
    auth: null
    headers: null
    json: false
    cookies: true
    gzip: true
    failOnStatus: true
    method: "GET"
  }

  request = (options) =>
    new Promise (resolve) ->
      Cypress.trigger "request", options, resolve

  argIsHttpMethod = (str) ->
    _.isString(str) and validHttpMethodsRe.test str.toUpperCase()

  isValidJsonObj = (body) ->
    _.isObject(body) and not _.isFunction(body)

  whichAreUntruthyAndOptional = (val, key) ->
    !val and key in optionalOpts

  # Cypress.extend
  #   ## set defaults for all requests?
  #   requestDefaults: (options = {}) ->

  Cypress.addParentCommand
    ## allow our signature to be similar to cy.route
    ## METHOD / URL / BODY
    ## or object literal with all expanded options
    request: (args...) ->
      options = o = {}

      switch
        when _.isObject(args[0])
          _.extend options, args[0]

        when args.length is 1
          o.url = args[0]

        when args.length is 2
          ## if our first arg is a valid
          ## HTTP method then set method + url
          if argIsHttpMethod(args[0])
            o.method = args[0]
            o.url    = args[1]
          else
            ## set url + body
            o.url    = args[0]
            o.body   = args[1]

        when args.length is 3
          o.method = args[0]
          o.url    = args[1]
          o.body   = args[2]

      _.defaults options, defaults, {
        domain: window.location.hostname
        timeout: Cypress.config("responseTimeout")
      }

      options.method = options.method.toUpperCase()

      if not validHttpMethodsRe.test(options.method)
        $Cypress.Utils.throwErrByPath("request.invalid_method", {
          args: { method: o.method }
        })

      if not options.url
        $Cypress.Utils.throwErrByPath("request.url_missing")

      if not _.isString(options.url)
        $Cypress.Utils.throwErrByPath("request.url_wrong_type")

      ## normalize the url by prepending it with our current origin
      ## or the baseUrl
      ## or just using the options.url if its FQDN
      ## origin may return an empty string if we haven't visited anything yet
      originOrBase = @_getLocation("origin") or @Cypress.config("baseUrl")
      options.url = Cypress.Location.getRemoteUrl(options.url, originOrBase)

      ## if options.url isnt FQDN then we need to throw here
      ## if we made a request prior to a visit then it needs
      ## to be filled out
      if not Cypress.Location.isFullyQualifiedUrl(options.url)
        $Cypress.Utils.throwErrByPath("request.url_invalid")

      if isValidJsonObj(options.body)
        options.json = true

      options = _.omit options, whichAreUntruthyAndOptional

      if a = options.auth
        if not _.isObject(a)
          $Cypress.Utils.throwErrByPath("request.auth_invalid")

      if h = options.headers
        if _.isObject(h)
          options.headers = h
        else
          $Cypress.Utils.throwErrByPath("request.headers_invalid")

      isPlainObject = (obj) ->
        _.isObject(obj) and not _.isArray(obj) and not _.isFunction(obj)

      if c = options.cookies
        if not _.isBoolean(c) and not isPlainObject(c)
          $Cypress.Utils.throwErrByPath("request.cookies_invalid")

      if not _.isBoolean(options.gzip)
        $Cypress.Utils.throwErrByPath("request.gzip_invalid")

      ## clone the requestOpts to prevent
      ## anything from mutating it now
      requestOpts = _(options).pick("method", "url", "body", "headers", "cookies", "json", "auth", "gzip", "domain")

      if options.log
        options._log = Cypress.Log.command({
          message: ""
          consoleProps: -> {
            Request: requestOpts
            Returned: options.response
          }

          renderProps: ->
            status = switch
              when r = options.response
                r.status
              else
                indicator = "pending"
                "---"

            indicator ?= if isOkStatusCodeRe.test(status) then "successful" else "bad"

            {
              displayMessage: "#{options.method} #{status} #{_.truncate(options.url, 25)}"
              indicator: indicator
            }
        })

      ## need to remove the current timeout
      ## because we're handling timeouts ourselves
      @_clearTimeout()

      request(requestOpts)
        .timeout(options.timeout)
        .then (response) =>
          options.response = response

          if err = response.__error
            body = if b = requestOpts.body
              "Body: #{Cypress.Utils.stringify(b)}"
            else
              ""

            headers = if h = requestOpts.headers
              "Headers: #{Cypress.Utils.stringify(h)}"
            else
              ""

            $Cypress.Utils.throwErrByPath("request.loading_failed", {
              onFail: options._log
              args: {
                error: err
                method: requestOpts.method
                url: requestOpts.url
                body
                headers
              }
            })

          ## bomb if we should fail on non 2xx status code
          if options.failOnStatus and not isOkStatusCodeRe.test(response.status)
            $Cypress.Utils.throwErrByPath("request.status_invalid", {
              onFail: options._log
              args: { status: response.status }
            })

          return response
        .catch Promise.TimeoutError, (err) =>
          $Cypress.Utils.throwErrByPath "request.timed_out", {
            onFail: options._log
            args: { timeout: options.timeout }
          }
