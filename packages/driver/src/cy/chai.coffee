_ = require("lodash")
$ = require("jquery")
chai = require("chai")
chaijQuery = require("chai-jquery")
sinonChai = require("@cypress/sinon-chai")

dom = require("../cypress/dom")
$utils = require("../cypress/utils")

## all words between single quotes which are at
## the end of the string
allPropertyWordsBetweenSingleQuotes = /('.*?')$/g

## grab all words between single quotes except
## when the single quote word is the LAST word
allButLastWordsBetweenSingleQuotes = /('.*?')(.+)/g

allBetweenFourStars = /\*\*.*\*\*/
allSingleQuotes = /'/g
allEscapedSingleQuotes = /\\'/g
allQuoteMarkers = /__quote__/g
allWordsBetweenCurlyBraces  = /(#{.+?})/g
allQuadStars = /\*\*\*\*/g

assertProto = null
matchProto = null
lengthProto = null
containProto = null
existProto = null
visibleProto = null
getMessage = null
chaiUtils = null

chai.use(sinonChai)

chai.use (chai, u) ->
  chaiUtils = u

  chaijQuery(chai, chaiUtils, $)

  assertProto  = chai.Assertion::assert
  matchProto   = chai.Assertion::match
  lengthProto  = chai.Assertion::__methods.length.method
  containProto = chai.Assertion::__methods.contain.method
  existProto   = Object.getOwnPropertyDescriptor(chai.Assertion::, "exist").get
  visibleProto = Object.getOwnPropertyDescriptor(chai.Assertion::, "visible").get
  getMessage   = chaiUtils.getMessage

  patchChaiMethod = (fn, key) ->
    chai[key] = _.wrap fn, (orig, args...) ->

      args = _.map args, (arg) ->
        ## if the object in the arguments has a cypress namespace
        ## then swap it out for that object
        if obj = $utils.getCypressNamespace(arg)
          return obj

        return arg

      orig.apply(@, args)

  removeOrKeepSingleQuotesBetweenStars = (message) ->
    ## remove any single quotes between our **, preserving escaped quotes
    ## and if an empty string, put the quotes back
    message.replace allBetweenFourStars, (match) ->
      match
        .replace(allEscapedSingleQuotes, "__quote__") # preserve escaped quotes
        .replace(allSingleQuotes, "")
        .replace(allQuoteMarkers, "'") ## put escaped quotes back
        .replace(allQuadStars, "**''**") ## fix empty strings that end up as ****

  replaceArgMessages = (args, str) ->
    _.reduce args, (memo, value, index) =>
      if _.isString(value)
        value = value
          .replace(allWordsBetweenCurlyBraces,          "**$1**")
          .replace(allEscapedSingleQuotes,              "__quote__")
          .replace(allButLastWordsBetweenSingleQuotes,  "**$1**$2")
          .replace(allPropertyWordsBetweenSingleQuotes, "**$1**")
        memo.push value
      else
        memo.push value

      memo
    , []

  restoreAsserts = ->
    chaiUtils.getMessage = getMessage

    chai.Assertion::assert = assertProto
    chai.Assertion::match = matchProto
    chai.Assertion::__methods.length.method = lengthProto
    chai.Assertion::__methods.contain.method = containProto

    Object.defineProperty(chai.Assertion::, "exist", {get: existProto})
    Object.defineProperty(chai.Assertion::, "visible", {get: visibleProto})

  overrideChaiAsserts = (assertFn, isInDom) ->
    _this = @

    chaiUtils.getMessage = (assert, args) ->
      obj = assert._obj

      ## if we are formatting a DOM object
      if $utils.hasElement(obj) or $utils.hasWindow(obj) or $utils.hasDocument(obj)
        ## replace object with our formatted one
        assert._obj = $utils.stringifyElement(obj, "short")

      msg = getMessage.call(@, assert, args)

      ## restore the real obj if we changed it
      if obj isnt assert._obj
        assert._obj = obj

      return msg

    chai.Assertion.overwriteMethod "match", (_super) ->
      return (regExp) ->
        if _.isRegExp(regExp) or $utils.hasElement(@_obj)
          _super.apply(@, arguments)
        else
          err = $utils.cypressErr($utils.errMessageByPath("chai.match_invalid_argument", { regExp }))
          err.retry = false
          throw err

    chai.Assertion.overwriteChainableMethod "contain",
      fn1 = (_super) ->
        return (text) ->
          obj = @_obj

          if not ($utils.isJqueryInstance(obj) or $utils.hasElement(obj))
            return _super.apply(@, arguments)

          escText = $utils.escapeQuotes(text)

          selector = ":contains('#{escText}'), [type='submit'][value~='#{escText}']"

          @assert(
            obj.is(selector) or !!obj.find(selector).length
            "expected \#{this} to contain \#{exp}"
            "expected \#{this} not to contain \#{exp}"
            text
          )

      fn2 = (_super) ->
        return ->
          _super.apply(@, arguments)

    chai.Assertion.overwriteChainableMethod "length",
      fn1 = (_super) ->
        return (length) ->
          obj = @_obj

          if not ($utils.isJqueryInstance(obj) or $utils.hasElement(obj))
            return _super.apply(@, arguments)

          length = $utils.normalizeNumber(length)

          ## filter out anything not currently in our document
          if not isInDom(obj)
            obj = @_obj = obj.filter (index, el) ->
              isInDom(el)

          node = if obj and obj.length then $utils.stringifyElement(obj, "short") else obj.selector

          ## if our length assertion fails we need to check to
          ## ensure that the length argument is a finite number
          ## because if its not, we need to bail on retrying
          try
            @assert(
              obj.length is length,
              "expected '#{node}' to have a length of \#{exp} but got \#{act}",
              "expected '#{node}' to not have a length of \#{act}",
              length,
              obj.length
            )

          catch e1
            e1.node = node
            e1.negated = chaiUtils.flag(@, "negate")
            e1.type = "length"

            if _.isFinite(length)
              getLongLengthMessage = (len1, len2) ->
                if len1 > len2
                  "Too many elements found. Found '#{len1}', expected '#{len2}'."
                else
                  "Not enough elements found. Found '#{len1}', expected '#{len2}'."

              e1.displayMessage = getLongLengthMessage(obj.length, length)
              throw e1

            e2 = $utils.cypressErr($utils.errMessageByPath("chai.length_invalid_argument", { length }))
            e2.retry = false
            throw e2

      fn2 = (_super) ->
        return ->
          _super.apply(@, arguments)

    chai.Assertion.overwriteProperty "visible", (_super) ->
      return ->
        try
          _super.apply(@, arguments)
        catch e
          ## add reason hidden unless we expect the element to be hidden
          if (e.message or "").indexOf("not to be") is -1
            reason = dom.getReasonElIsHidden(@_obj)
            e.message += "\n\n" + reason
          throw e

    chai.Assertion.overwriteProperty "exist", (_super) ->
      return ->
        obj = @_obj

        if not ($utils.isJqueryInstance(obj) or $utils.hasElement(obj))
          try
            _super.apply(@, arguments)
          catch e
            e.type = "existence"
            throw e
        else
          if not obj.length
            @_obj = null

          node = if obj and obj.length then $utils.stringifyElement(obj, "short") else obj.selector

          try
            @assert(
              isContained = isInDom(obj),
              "expected \#{act} to exist in the DOM",
              "expected \#{act} not to exist in the DOM",
              node,
              node
            )
          catch e1
            e1.node = node
            e1.negated = chaiUtils.flag(@, "negate")
            e1.type = "existence"

            getLongExistsMessage = (obj) ->
              ## if we expected not for an element to exist
              if isContained
                "Expected #{node} not to exist in the DOM, but it was continuously found."
              else
                "Expected to find element: '#{obj.selector}', but never found it."

            e1.displayMessage = getLongExistsMessage(obj)
            throw e1

  createPatchedAssert = (assertFn) ->
    return (args...) ->
      passed    = chaiUtils.test(@, args)
      value     = chaiUtils.flag(@, "object")
      expected  = args[3]

      customArgs = replaceArgMessages(args, @_obj)

      message   = chaiUtils.getMessage(@, customArgs)
      actual    = chaiUtils.getActual(@, customArgs)

      message = removeOrKeepSingleQuotesBetweenStars(message)

      try
        assertProto.apply(@, args)
      catch e
        err = e

      assertFn(passed, message, value, actual, expected, err)

      throw err if err

  overrideExpect = (assertFn) ->
    patchedAssert = createPatchedAssert(assertFn)

    ## only override assertions for this specific
    ## expect function instance so we do not affect
    ## the outside world
    return (val, message) ->
      ## make the assertion
      ret = new chai.Assertion(val, message)

      ## replace the assert function
      ## for this assertion instance
      ret.assert = patchedAssert

      ## return assertion instance
      return ret

  overrideAssert = (assertFn) ->
    patchedAssert = createPatchedAssert(assertFn)

    tryCatchFinally = (fn) ->
      try
        fn()
      catch err
      finally
        ## always reset the prototype method
        chai.Assertion.prototype.assert = assertProto

      throw err if err

      return undefined

    fn = (express, errmsg) ->
      chai.Assertion.prototype.assert = patchedAssert

      tryCatchFinally ->
        chai.assert(express, errmsg)

    fns = _.functions(chai.assert)

    _.each fns, (name) ->
      fn[name] = ->
        args = arguments

        chai.Assertion.prototype.assert = patchedAssert

        tryCatchFinally =>
          chai.assert[name].apply(@, args)

    return fn

  setSpecWindowGlobals = (specWindow, assertFn) ->
    expect = overrideExpect(assertFn)
    assert = overrideAssert(assertFn)

    specWindow.chai   = chai
    specWindow.expect = expect
    specWindow.assert = assert

    return {
      chai
      expect
      assert
    }

  create = (specWindow, assertFn, isInDom) ->
    # restoreOverrides()
    restoreAsserts()

    # overrideChai()
    overrideChaiAsserts(assertFn, isInDom)

    return setSpecWindowGlobals(specWindow, assertFn)

  module.exports = {
    replaceArgMessages

    removeOrKeepSingleQuotesBetweenStars

    patchChaiMethod

    setSpecWindowGlobals

    # overrideChai: overrideChai

    restoreAsserts

    overrideExpect

    overrideChaiAsserts

    create
  }
