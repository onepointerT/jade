((f) ->
  if typeof exports == 'object' and typeof module != 'undefined'
    module.exports = f()
  else if typeof define == 'function' and define.amd
    define [], f
  else
    g = undefined
    if typeof window != 'undefined'
      g = window
    else if typeof global != 'undefined'
      g = global
    else if typeof self != 'undefined'
      g = self
    else
      g = this
    g.jade = f()
  return
) ->
  define = undefined
  module = undefined
  exports = undefined
  ((t, n, r) ->
    i = typeof require == 'function' and require

    s = (o, u) ->
      if !n[o]
        if !t[o]
          a = typeof require == 'function' and require
          if !u and a
            return a(o, !0)
          if i
            return i(o, !0)
          f = new Error('Cannot find module \'' + o + '\'')
          throw f.code = 'MODULE_NOT_FOUND'
          f

        l = n[o] = exports: {}
        t[o][0].call l.exports, ((e) ->
          `var n`
          n = t[o][1][e]
          s if n then n else e
        ), l, l.exports, e, t, n, r
      n[o].exports

    o = 0
    while o < r.length
      s r[o]
      o++
    s
  )({
    1: [
      (require, module, exports) ->

        ###*
        # Filter null `val`s.
        #
        # @param {*} val
        # @return {Boolean}
        # @api private
        ###

        nulls = (val) ->
          val != null and val != ''

        joinClasses = (val) ->
          (if Array.isArray(val) then val.map(joinClasses) else if val and typeof val == 'object' then Object.keys(val).filter(((key) ->
            val[key]
          )) else [ val ]).filter(nulls).join ' '

        jade_encode_char = (c) ->
          jade_encode_html_rules[c] or c

        jade_escape = (html) ->
          result = String(html).replace(jade_match_html, jade_encode_char)
          if result == '' + html
            html
          else
            result

        'use strict'

        ###*
        # Merge two attribute objects giving precedence
        # to values in object `b`. Classes are special-cased
        # allowing for arrays and merging/joining appropriately
        # resulting in a string.
        #
        # @param {Object} a
        # @param {Object} b
        # @return {Object} a
        # @api private
        ###

        exports.merge = (a, b) ->
          if arguments.length == 1
            attrs = a[0]
            i = 1
            while i < a.length
              attrs = merge(attrs, a[i])
              i++
            return attrs
          ac = a['class']
          bc = b['class']
          if ac or bc
            ac = ac or []
            bc = bc or []
            if !Array.isArray(ac)
              ac = [ ac ]
            if !Array.isArray(bc)
              bc = [ bc ]
            a['class'] = ac.concat(bc).filter(nulls)
          for key of b
            if key != 'class'
              a[key] = b[key]
          a

        ###*
        # join array as classes.
        #
        # @param {*} val
        # @return {String}
        ###

        exports.joinClasses = joinClasses

        ###*
        # Render the given classes.
        #
        # @param {Array} classes
        # @param {Array.<Boolean>} escaped
        # @return {String}
        ###

        exports.cls = (classes, escaped) ->
          buf = []
          i = 0
          while i < classes.length
            if escaped and escaped[i]
              buf.push exports.escape(joinClasses([ classes[i] ]))
            else
              buf.push joinClasses(classes[i])
            i++
          text = joinClasses(buf)
          if text.length
            ' class="' + text + '"'
          else
            ''

        exports.style = (val) ->
          if val and typeof val == 'object'
            Object.keys(val).map((style) ->
              style + ':' + val[style]
            ).join ';'
          else
            val

        ###*
        # Render the given attribute.
        #
        # @param {String} key
        # @param {String} val
        # @param {Boolean} escaped
        # @param {Boolean} terse
        # @return {String}
        ###

        exports.attr = (key, val, escaped, terse) ->
          if key == 'style'
            val = exports.style(val)
          if 'boolean' == typeof val or null == val
            if val
              ' ' + (if terse then key else key + '="' + key + '"')
            else
              ''
          else if 0 == key.indexOf('data') and 'string' != typeof val
            if JSON.stringify(val).indexOf('&') != -1
              console.warn 'Since Jade 2.0.0, ampersands (`&`) in data attributes ' + 'will be escaped to `&amp;`'
            if val and typeof val.toISOString == 'function'
              console.warn 'Jade will eliminate the double quotes around dates in ' + 'ISO form after 2.0.0'
            ' ' + key + '=\'' + JSON.stringify(val).replace(/'/g, '&apos;') + '\''
          else if escaped
            if val and typeof val.toISOString == 'function'
              console.warn 'Jade will stringify dates in ISO form after 2.0.0'
            ' ' + key + '="' + exports.escape(val) + '"'
          else
            if val and typeof val.toISOString == 'function'
              console.warn 'Jade will stringify dates in ISO form after 2.0.0'
            ' ' + key + '="' + val + '"'

        ###*
        # Render the given attributes object.
        #
        # @param {Object} obj
        # @param {Object} escaped
        # @return {String}
        ###

        exports.attrs = (obj, terse) ->
          buf = []
          keys = Object.keys(obj)
          if keys.length
            i = 0
            while i < keys.length
              key = keys[i]
              val = obj[key]
              if 'class' == key
                if val = joinClasses(val)
                  buf.push ' ' + key + '="' + val + '"'
              else
                buf.push exports.attr(key, val, false, terse)
              ++i
          buf.join ''

        ###*
        # Escape the given string of `html`.
        #
        # @param {String} html
        # @return {String}
        # @api private
        ###

        jade_encode_html_rules = 
          '&': '&amp;'
          '<': '&lt;'
          '>': '&gt;'
          '"': '&quot;'
        jade_match_html = /[&<>"]/g
        exports.escape = jade_escape

        ###*
        # Re-throw the given `err` in context to the
        # the jade in `filename` at the given `lineno`.
        #
        # @param {Error} err
        # @param {String} filename
        # @param {String} lineno
        # @api private
        ###

        exports.rethrow = (err, filename, lineno, str) ->
          `var context`
          if !(err instanceof Error)
            throw err
          if (typeof window != 'undefined' or !filename) and !str
            err.message += ' on line ' + lineno
            throw err
          try
            str = str or require('fs').readFileSync(filename, 'utf8')
          catch ex
            rethrow err, null, lineno
          context = 3
          lines = str.split('\n')
          start = Math.max(lineno - context, 0)
          end = Math.min(lines.length, lineno + context)
          # Error context
          context = lines.slice(start, end).map((line, i) ->
            curr = i + start + 1
            (if curr == lineno then '  > ' else '    ') + curr + '| ' + line
          ).join('\n')
          # Alter exception message
          err.path = filename
          err.message = (filename or 'Jade') + ':' + lineno + '\n' + context + '\n\n' + err.message
          throw err
          return

        exports.DebugItem = (lineno, filename) ->
          @lineno = lineno
          @filename = filename
          return

        return
      { 'fs': 2 }
    ]
    2: [
      (require, module, exports) ->
      {}
    ]
  }, {}, [ 1 ]) 1
