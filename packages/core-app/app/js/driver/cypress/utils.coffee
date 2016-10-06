$Cypress.Utils = do ($Cypress, _) ->

  tagOpen     = /\[([a-z\s='"-]+)\]/g
  tagClosed   = /\[\/([a-z]+)\]/g
  quotesRe    = /('|")/g

  CYPRESS_OBJECT_NAMESPACE = "_cypressObj"

  defaultOptions = {
    delay: 10
    force: false
    timeout: null
    interval: null
    multiple: false
    waitOnAnimations: null
    animationDistanceThreshold: null
  }

  return {
    warning: (msg) ->
      console.warn("Cypress Warning: " + msg)

    throwErr: (err, options = {}) ->
      if _.isString(err)
        err = @cypressErr(err)

      onFail = options.onFail
      ## assume onFail is a command if
      ## onFail is present and isnt a function
      if onFail and not _.isFunction(onFail)
        command = onFail

        ## redefine onFail and automatically
        ## hook this into our command
        onFail = (err) ->
          command.error(err)

      err.onFail = onFail if onFail

      throw err

    throwErrByPath: (errPath, options = {}) ->
      err = try
        @errMessageByPath errPath, options.args
      catch e
        err = @internalErr e

      @throwErr(err, options)

    internalErr: (err) ->
      err = new Error(err)
      err.name = "InternalError"
      err

    cypressErr: (err) ->
      err = new Error(err)
      err.name = "CypressError"
      err

    errMessageByPath: (errPath, args) ->
      if not errMessage = @getObjValueByPath $Cypress.ErrorMessages, errPath
        throw new Error "Error message path '#{errPath}' does not exist"

      if _.isFunction(errMessage)
        errMessage(args)
      else
        _.reduce args, (message, argValue, argKey) ->
          message.replace(new RegExp("\{\{#{argKey}\}\}", "g"), argValue)
        , errMessage

    normalizeObjWithLength: (obj) ->
      ## underscore shits the bed if our object has a 'length'
      ## property so we have to normalize that
      if _(obj).has("length")
        obj.Length = obj.length
        delete obj.length

      obj

    ## return a new object if the obj
    ## contains the properties of filter
    ## and the values are different
    filterOutOptions: (obj, filter = {}) ->
      _.defaults filter, defaultOptions

      @normalizeObjWithLength(filter)

      whereFilterHasSameKeyButDifferentValue = (value, key) ->
        upperKey = _.capitalize(key)

        (_(filter).has(key) or _(filter).has(upperKey)) and
          filter[key] isnt value

      obj = _.pick(obj, whereFilterHasSameKeyButDifferentValue)

      if _.isEmpty(obj) then undefined else obj

    _stringifyObj: (obj) ->
      obj = @normalizeObjWithLength(obj)

      str = _.reduce obj, (memo, value, key) =>
        memo.push key.toLowerCase() + ": " + @_stringify(value)
        memo
      , []

      "{" + str.join(", ") + "}"

    _stringify: (value) ->
      switch
        when @hasElement(value)
          @stringifyElement(value, "short")

        when _.isFunction(value)
          "function(){}"

        when _.isArray(value)
          len = value.length
          if len > 3
            "Array[#{len}]"
          else
            "[" + _.map(value, _.bind(@_stringify, @)).join(", ") + "]"

        when _.isRegExp(value)
          value.toString()

        when _.isObject(value)
          len = _.keys(value).length
          if len > 2
            "Object{#{len}}"
          else
            @_stringifyObj(value)

        when _.isUndefined(value)
          undefined

        else
          "" + value

    stringify: (values) ->
      ## if we already have an array
      ## then nest it again so that
      ## its formatted properly
      values = [].concat(values)

      _.chain(values)
        .map(_.bind(@_stringify, @))
          .without(undefined)
            .value()
              .join(", ")

    hasWindow: (obj) ->
      try
        !!(obj and $.isWindow(obj[0])) or $.isWindow(obj)
      catch
        false

    hasElement: (obj) ->
      try
        !!(obj and obj[0] and _.isElement(obj[0])) or _.isElement(obj)
      catch
        false

    hasDocument: (obj) ->
      try
        !!((obj and obj.nodeType is 9) or (obj and obj[0] and obj[0].nodeType is 9))
      catch
        false

    isDescendent: ($el1, $el2) ->
      return false if not $el2

      !!(($el1.get(0) is $el2.get(0)) or $el1.has($el2).length)

    getDomElements: ($el) ->
      return if not $el?.length

      if $el.length is 1
        $el.get(0)
      else
        _.reduce $el, (memo, el) ->
          memo.push(el)
          memo
        , []

    ## short form css-inlines the element
    ## long form returns the outerHTML
    stringifyElement: (el, form = "long") ->
      ## if we are formatting the window object
      if @hasWindow(el)
        return "<window>"

      ## if we are formatting the document object
      if @hasDocument(el)
        return "<document>"

      $el = if _.isElement(el) then $(el) else el

      switch form
        when "long"
          text     = _.chain($el.text()).clean().truncate(10).value()
          children = $el.children().length
          str      = $el.clone().empty().prop("outerHTML")
          switch
            when children then str.replace("></", ">...</")
            when text     then str.replace("></", ">#{text}</")
            else
              str
        when "short"
          str = $el.prop("tagName").toLowerCase()
          if id = $el.prop("id")
            str += "#" + id

          ## using attr here instead of class because
          ## svg's return an SVGAnimatedString object
          ## instead of a normal string when calling
          ## the property 'class'
          if klass = $el.attr("class")
            str += "." + klass.split(/\s+/).join(".")

          ## if we have more than one element,
          ## format it so that the user can see there's more
          if $el.length > 1
            "[ <#{str}>, #{$el.length - 1} more... ]"
          else
            "<#{str}>"

    plural: (obj, plural, singular) ->
      obj = if _.isNumber(obj) then obj else obj.length
      if obj > 1 then plural else singular

    convertHtmlTags: (html) ->
      html
        .replace(tagOpen, "<$1>")
        .replace(tagClosed, "</$1>")

    isInstanceOf: (instance, constructor) ->
      try
        instance instanceof constructor
      catch e
        false

    escapeQuotes: (text) ->
      ## convert to str and escape any single
      ## or double quotes
      ("" + text).replace(quotesRe, "\\$1")

    getCypressNamespace: (obj) ->
      obj and obj[CYPRESS_OBJECT_NAMESPACE]

    ## backs up an original object to another
    ## by going through the cypress object namespace
    setCypressNamespace: (obj, original) ->
      obj[CYPRESS_OBJECT_NAMESPACE] = original

    getObjValueByPath: (obj, keyPath) ->
      if not _.isObject obj
        throw new Error "The first parameter to $Cypress.Utils.getObjValueByPath() must be an object"
      if not _.isString keyPath
        throw new Error "The second parameter to $Cypress.Utils.getObjValueByPath() must be a string"
      keys = keyPath.split '.'
      val = obj
      for key in keys
        val = val[key]
        break unless val
      val
  }
