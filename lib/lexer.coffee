assertExpression = (exp) ->
  #this verifies that a JavaScript expression is valid
  Function '', 'return (' + exp + ')'
  return

assertNestingCorrect = (exp) ->
  #this verifies that code is properly nested, but allows
  #invalid JavaScript such as the contents of `attributes`
  res = characterParser(exp)
  if res.isNesting()
    throw new Error('Nesting must match on expression `' + exp + '`')
  return

'use strict'
utils = require('./utils')
characterParser = require('character-parser')

###*
# Initialize `Lexer` with the given `str`.
#
# @param {String} str
# @param {String} filename
# @api private
###

Lexer = 
module.exports = (str, filename) ->
  @input = str.replace(/\r\n|\r/g, '\n')
  @filename = filename
  @deferredTokens = []
  @lastIndents = 0
  @lineno = 1
  @stash = []
  @indentStack = []
  @indentRe = null
  @pipeless = false
  return

###*
# Lexer prototype.
###

Lexer.prototype =
  tok: (type, val) ->
    {
      type: type
      line: @lineno
      val: val
    }
  consume: (len) ->
    @input = @input.substr(len)
    return
  scan: (regexp, type) ->
    captures = undefined
    if captures = regexp.exec(@input)
      @consume captures[0].length
      return @tok(type, captures[1])
    return
  defer: (tok) ->
    @deferredTokens.push tok
    return
  lookahead: (n) ->
    fetch = n - (@stash.length)
    while fetch-- > 0
      @stash.push @next()
    @stash[--n]
  bracketExpression: (skip) ->
    skip = skip or 0
    start = @input[skip]
    if start != '(' and start != '{' and start != '['
      throw new Error('unrecognized start character')
    end = {
      '(': ')'
      '{': '}'
      '[': ']'
    }[start]
    range = characterParser.parseMax(@input, start: skip + 1)
    if @input[range.end] != end
      throw new Error('start character ' + start + ' does not match end character ' + @input[range.end])
    range
  stashed: ->
    @stash.length and @stash.shift()
  deferred: ->
    @deferredTokens.length and @deferredTokens.shift()
  eos: ->
    if @input.length
      return
    if @indentStack.length
      @indentStack.shift()
      @tok 'outdent'
    else
      @tok 'eos'
  blank: ->
    captures = undefined
    if captures = /^\n *\n/.exec(@input)
      @consume captures[0].length - 1
      ++@lineno
      if @pipeless
        return @tok('text', '')
      return @next()
    return
  comment: ->
    captures = undefined
    if captures = /^\/\/(-)?([^\n]*)/.exec(@input)
      @consume captures[0].length
      tok = @tok('comment', captures[2])
      tok.buffer = '-' != captures[1]
      @pipeless = true
      return tok
    return
  interpolation: ->
    if /^#\{/.test(@input)
      match = @bracketExpression(1)
      @consume match.end + 1
      return @tok('interpolation', match.src)
    return
  tag: ->
    captures = undefined
    if captures = /^(\w[-:\w]*)(\/?)/.exec(@input)
      @consume captures[0].length
      tok = undefined
      name = captures[1]
      if ':' == name[name.length - 1]
        name = name.slice(0, -1)
        tok = @tok('tag', name)
        @defer @tok(':')
        if @input[0] != ' '
          console.warn 'Warning: space required after `:` on line ' + @lineno + ' of jade file "' + @filename + '"'
        while ' ' == @input[0]
          @input = @input.substr(1)
      else
        tok = @tok('tag', name)
      tok.selfClosing = ! !captures[2]
      return tok
    return
  filter: ->
    tok = @scan(/^:([\w\-]+)/, 'filter')
    if tok
      @pipeless = true
      return tok
    return
  doctype: ->
    if @scan(/^!!! *([^\n]+)?/, 'doctype')
      throw new Error('`!!!` is deprecated, you must now use `doctype`')
    node = @scan(/^(?:doctype) *([^\n]+)?/, 'doctype')
    if node and node.val and node.val.trim() == '5'
      throw new Error('`doctype 5` is deprecated, you must now use `doctype html`')
    node
  id: ->
    @scan /^#([\w-]+)/, 'id'
  className: ->
    @scan /^\.([\w-]+)/, 'class'
  text: ->
    @scan(/^(?:\| ?| )([^\n]+)/, 'text') or @scan(/^\|?( )/, 'text') or @scan(/^(<[^\n]*)/, 'text')
  textFail: ->
    tok = undefined
    if tok = @scan(/^([^\.\n][^\n]+)/, 'text')
      console.warn 'Warning: missing space before text for line ' + @lineno + ' of jade file "' + @filename + '"'
      return tok
    return
  dot: ->
    match = undefined
    if match = @scan(/^\./, 'dot')
      @pipeless = true
      return match
    return
  'extends': ->
    @scan /^extends? +([^\n]+)/, 'extends'
  prepend: ->
    captures = undefined
    if captures = /^prepend +([^\n]+)/.exec(@input)
      @consume captures[0].length
      mode = 'prepend'
      name = captures[1]
      tok = @tok('block', name)
      tok.mode = mode
      return tok
    return
  append: ->
    captures = undefined
    if captures = /^append +([^\n]+)/.exec(@input)
      @consume captures[0].length
      mode = 'append'
      name = captures[1]
      tok = @tok('block', name)
      tok.mode = mode
      return tok
    return
  block: ->
    captures = undefined
    if captures = /^block\b *(?:(prepend|append) +)?([^\n]+)/.exec(@input)
      @consume captures[0].length
      mode = captures[1] or 'replace'
      name = captures[2]
      tok = @tok('block', name)
      tok.mode = mode
      return tok
    return
  mixinBlock: ->
    captures = undefined
    if captures = /^block[ \t]*(\n|$)/.exec(@input)
      @consume captures[0].length - (captures[1].length)
      return @tok('mixin-block')
    return
  'yield': ->
    @scan /^yield */, 'yield'
  include: ->
    @scan /^include +([^\n]+)/, 'include'
  includeFiltered: ->
    captures = undefined
    if captures = /^include:([\w\-]+)([\( ])/.exec(@input)
      @consume captures[0].length - 1
      filter = captures[1]
      attrs = if captures[2] == '(' then @attrs() else null
      if !(captures[2] == ' ' or @input[0] == ' ')
        throw new Error('expected space after include:filter but got ' + utils.stringify(@input[0]))
      captures = /^ *([^\n]+)/.exec(@input)
      if !captures or captures[1].trim() == ''
        throw new Error('missing path for include:filter')
      @consume captures[0].length
      path = captures[1]
      tok = @tok('include', path)
      tok.filter = filter
      tok.attrs = attrs
      return tok
    return
  'case': ->
    @scan /^case +([^\n]+)/, 'case'
  when: ->
    @scan /^when +([^:\n]+)/, 'when'
  'default': ->
    @scan /^default */, 'default'
  call: ->
    tok = undefined
    captures = undefined
    if captures = /^\+(\s*)(([-\w]+)|(#\{))/.exec(@input)
      # try to consume simple or interpolated call
      if captures[3]
        # simple call
        @consume captures[0].length
        tok = @tok('call', captures[3])
      else
        # interpolated call
        match = @bracketExpression(2 + captures[1].length)
        @consume match.end + 1
        assertExpression match.src
        tok = @tok('call', '#{' + match.src + '}')
      # Check for args (not attributes)
      if captures = /^ *\(/.exec(@input)
        range = @bracketExpression(captures[0].length - 1)
        if !/^\s*[-\w]+ *=/.test(range.src)
          # not attributes
          @consume range.end + 1
          tok.args = range.src
        if tok.args
          assertExpression '[' + tok.args + ']'
      return tok
    return
  mixin: ->
    captures = undefined
    if captures = /^mixin +([-\w]+)(?: *\((.*)\))? */.exec(@input)
      @consume captures[0].length
      tok = @tok('mixin', captures[1])
      tok.args = captures[2]
      return tok
    return
  conditional: ->
    captures = undefined
    if captures = /^(if|unless|else if|else)\b([^\n]*)/.exec(@input)
      @consume captures[0].length
      type = captures[1]
      js = captures[2]
      isIf = false
      isElse = false
      switch type
        when 'if'
          assertExpression js
          js = 'if (' + js + ')'
          isIf = true
        when 'unless'
          assertExpression js
          js = 'if (!(' + js + '))'
          isIf = true
        when 'else if'
          assertExpression js
          js = 'else if (' + js + ')'
          isIf = true
          isElse = true
        when 'else'
          if js and js.trim()
            throw new Error('`else` cannot have a condition, perhaps you meant `else if`')
          js = 'else'
          isElse = true
      tok = @tok('code', js)
      tok.isElse = isElse
      tok.isIf = isIf
      tok.requiresBlock = true
      return tok
    return
  'while': ->
    captures = undefined
    if captures = /^while +([^\n]+)/.exec(@input)
      @consume captures[0].length
      assertExpression captures[1]
      tok = @tok('code', 'while (' + captures[1] + ')')
      tok.requiresBlock = true
      return tok
    return
  each: ->
    captures = undefined
    if captures = /^(?:- *)?(?:each|for) +([a-zA-Z_$][\w$]*)(?: *, *([a-zA-Z_$][\w$]*))? * in *([^\n]+)/.exec(@input)
      @consume captures[0].length
      tok = @tok('each', captures[1])
      tok.key = captures[2] or '$index'
      assertExpression captures[3]
      tok.code = captures[3]
      return tok
    return
  code: ->
    captures = undefined
    if captures = /^(!?=|-)[ \t]*([^\n]+)/.exec(@input)
      @consume captures[0].length
      flags = captures[1]
      captures[1] = captures[2]
      tok = @tok('code', captures[1])
      tok.escape = flags.charAt(0) == '='
      tok.buffer = flags.charAt(0) == '=' or flags.charAt(1) == '='
      if tok.buffer
        assertExpression captures[1]
      return tok
    return
  blockCode: ->
    captures = undefined
    if captures = /^-\n/.exec(@input)
      @consume captures[0].length - 1
      tok = @tok('blockCode')
      @pipeless = true
      return tok
    return
  attrs: ->
    if '(' == @input.charAt(0)
      index = @bracketExpression().end
      str = @input.substr(1, index - 1)
      tok = @tok('attrs')
      assertNestingCorrect str
      quote = ''

      interpolate = (attr) ->
        attr.replace /(\\)?#\{(.+)/g, (_, escape, expr) ->
          if escape
            return _
          try
            range = characterParser.parseMax(expr)
            if expr[range.end] != '}'
              return _.substr(0, 2) + interpolate(_.substr(2))
            assertExpression range.src
            return quote + ' + (' + range.src + ') + ' + quote + interpolate(expr.substr(range.end + 1))
          catch ex
            return _.substr(0, 2) + interpolate(_.substr(2))
          return

      @consume index + 1
      tok.attrs = []
      escapedAttr = true
      key = ''
      val = ''
      interpolatable = ''
      state = characterParser.defaultState()
      loc = 'key'

      isEndOfAttribute = (i) ->
        `var x`
        if key.trim() == ''
          return false
        if i == str.length
          return true
        if loc == 'key'
          if str[i] == ' ' or str[i] == '\n'
            x = i
            while x < str.length
              if str[x] != ' ' and str[x] != '\n'
                if str[x] == '=' or str[x] == '!' or str[x] == ','
                  return false
                else
                  return true
              x++
          return str[i] == ','
        else if loc == 'value' and !state.isNesting()
          try
            assertExpression val
            if str[i] == ' ' or str[i] == '\n'
              x = i
              while x < str.length
                if str[x] != ' ' and str[x] != '\n'
                  if characterParser.isPunctuator(str[x]) and str[x] != '"' and str[x] != '\''
                    return false
                  else
                    return true
                x++
            return str[i] == ','
          catch ex
            return false
        return

      @lineno += str.split('\n').length - 1
      i = 0
      while i <= str.length
        if isEndOfAttribute(i)
          val = val.trim()
          if val
            assertExpression val
          key = key.trim()
          key = key.replace(/^['"]|['"]$/g, '')
          tok.attrs.push
            name: key
            val: if '' == val then true else val
            escaped: escapedAttr
          key = val = ''
          loc = 'key'
          escapedAttr = false
        else
          switch loc
            when 'key-char'
              if str[i] == quote
                loc = 'key'
                if i + 1 < str.length and [
                    ' '
                    ','
                    '!'
                    '='
                    '\n'
                  ].indexOf(str[i + 1]) == -1
                  throw new Error('Unexpected character ' + str[i + 1] + ' expected ` `, `\\n`, `,`, `!` or `=`')
              else
                key += str[i]
            when 'key'
              if key == '' and (str[i] == '"' or str[i] == '\'')
                loc = 'key-char'
                quote = str[i]
              else if str[i] == '!' or str[i] == '='
                escapedAttr = str[i] != '!'
                if str[i] == '!'
                  i++
                if str[i] != '='
                  throw new Error('Unexpected character ' + str[i] + ' expected `=`')
                loc = 'value'
                state = characterParser.defaultState()
              else
                key += str[i]
            when 'value'
              state = characterParser.parseChar(str[i], state)
              if state.isString()
                loc = 'string'
                quote = str[i]
                interpolatable = str[i]
              else
                val += str[i]
            when 'string'
              state = characterParser.parseChar(str[i], state)
              interpolatable += str[i]
              if !state.isString()
                loc = 'value'
                val += interpolate(interpolatable)
        i++
      if '/' == @input.charAt(0)
        @consume 1
        tok.selfClosing = true
      return tok
    return
  attributesBlock: ->
    captures = undefined
    if /^&attributes\b/.test(@input)
      @consume 11
      args = @bracketExpression()
      @consume args.end + 1
      return @tok('&attributes', args.src)
    return
  indent: ->
    captures = undefined
    re = undefined
    # established regexp
    if @indentRe
      captures = @indentRe.exec(@input)
      # determine regexp
    else
      # tabs
      re = /^\n(\t*) */
      captures = re.exec(@input)
      # spaces
      if captures and !captures[1].length
        re = /^\n( *)/
        captures = re.exec(@input)
      # established
      if captures and captures[1].length
        @indentRe = re
    if captures
      tok = undefined
      indents = captures[1].length
      ++@lineno
      @consume indents + 1
      if ' ' == @input[0] or '\u0009' == @input[0]
        throw new Error('Invalid indentation, you can use tabs or spaces but not both')
      # blank line
      if '\n' == @input[0]
        @pipeless = false
        return @tok('newline')
      # outdent
      if @indentStack.length and indents < @indentStack[0]
        while @indentStack.length and @indentStack[0] > indents
          @stash.push @tok('outdent')
          @indentStack.shift()
        tok = @stash.pop()
        # indent
      else if indents and indents != @indentStack[0]
        @indentStack.unshift indents
        tok = @tok('indent', indents)
        # newline
      else
        tok = @tok('newline')
      @pipeless = false
      return tok
    return
  pipelessText: ->
    if !@pipeless
      return
    captures = undefined
    re = undefined
    # established regexp
    if @indentRe
      captures = @indentRe.exec(@input)
      # determine regexp
    else
      # tabs
      re = /^\n(\t*) */
      captures = re.exec(@input)
      # spaces
      if captures and !captures[1].length
        re = /^\n( *)/
        captures = re.exec(@input)
      # established
      if captures and captures[1].length
        @indentRe = re
    indents = captures and captures[1].length
    if indents and (@indentStack.length == 0 or indents > @indentStack[0])
      indent = captures[1]
      line = undefined
      tokens = []
      isMatch = undefined
      loop
        # text has `\n` as a prefix
        i = @input.substr(1).indexOf('\n')
        if -1 == i
          i = @input.length - 1
        str = @input.substr(1, i)
        isMatch = str.substr(0, indent.length) == indent or !str.trim()
        if isMatch
          # consume test along with `\n` prefix if match
          @consume str.length + 1
          ++@lineno
          tokens.push str.substr(indent.length)
        unless @input.length and isMatch
          break
      while @input.length == 0 and tokens[tokens.length - 1] == ''
        tokens.pop()
      return @tok('pipeless-text', tokens)
    return
  colon: ->
    good = /^: +/.test(@input)
    res = @scan(/^: */, ':')
    if res and !good
      console.warn 'Warning: space required after `:` on line ' + @lineno + ' of jade file "' + @filename + '"'
    res
  fail: ->
    throw new Error('unexpected text ' + @input.substr(0, 5))
    return
  advance: ->
    @stashed() or @next()
  next: ->
    @deferred() or @blank() or @eos() or @pipelessText() or @yield() or @doctype() or @interpolation() or @['case']() or @when() or @['default']() or @['extends']() or @append() or @prepend() or @block() or @mixinBlock() or @include() or @includeFiltered() or @mixin() or @call() or @conditional() or @each() or @['while']() or @tag() or @filter() or @blockCode() or @code() or @id() or @className() or @attrs() or @attributesBlock() or @indent() or @text() or @comment() or @colon() or @dot() or @textFail() or @fail()
