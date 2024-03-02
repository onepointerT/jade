isConstant = (src) ->
  constantinople src,
    jade: runtime
    'jade_interp': undefined

toConstant = (src) ->
  constantinople.toConstant src,
    jade: runtime
    'jade_interp': undefined

errorAtNode = (node, error) ->
  error.line = node.line
  error.filename = node.filename
  error

'use strict'
nodes = require('./nodes')
filters = require('./filters')
doctypes = require('./doctypes')
runtime = require('./runtime')
utils = require('./utils')
selfClosing = require('void-elements')
parseJSExpression = require('character-parser').parseMax
constantinople = require('constantinople')

###*
# Initialize `Compiler` with the given `node`.
#
# @param {Node} node
# @param {Object} options
# @api public
###

Compiler = 
module.exports = (node, options) ->
  @options = options = options or {}
  @node = node
  @hasCompiledDoctype = false
  @hasCompiledTag = false
  @pp = options.pretty or false
  if @pp and typeof @pp != 'string'
    @pp = '  '
  @debug = false != options.compileDebug
  @indents = 0
  @parentIndents = 0
  @terse = false
  @mixins = {}
  @dynamicMixins = false
  if options.doctype
    @setDoctype options.doctype
  return

###*
# Compiler prototype.
###

Compiler.prototype =
  compile: ->
    @buf = []
    if @pp
      @buf.push 'var jade_indent = [];'
    @lastBufferedIdx = -1
    @visit @node
    if !@dynamicMixins
      # if there are no dynamic mixins we can remove any un-used mixins
      mixinNames = Object.keys(@mixins)
      i = 0
      while i < mixinNames.length
        mixin = @mixins[mixinNames[i]]
        if !mixin.used
          x = 0
          while x < mixin.instances.length
            y = mixin.instances[x].start
            while y < mixin.instances[x].end
              @buf[y] = ''
              y++
            x++
        i++
    @buf.join '\n'
  setDoctype: (name) ->
    @doctype = doctypes[name.toLowerCase()] or '<!DOCTYPE ' + name + '>'
    @terse = @doctype.toLowerCase() == '<!doctype html>'
    @xml = 0 == @doctype.indexOf('<?xml')
    return
  buffer: (str, interpolate) ->
    self = this
    if interpolate
      match = /(\\)?([#!]){((?:.|\n)*)$/.exec(str)
      if match
        @buffer str.substr(0, match.index), false
        if match[1]
          # escape
          @buffer match[2] + '{', false
          @buffer match[3], true
          return
        else
          rest = match[3]
          range = parseJSExpression(rest)
          code = (if '!' == match[2] then '' else 'jade.escape') + '((jade_interp = ' + range.src + ') == null ? \'\' : jade_interp)'
          @bufferExpression code
          @buffer rest.substr(range.end + 1), true
          return
    str = utils.stringify(str)
    str = str.substr(1, str.length - 2)
    if @lastBufferedIdx == @buf.length
      if @lastBufferedType == 'code'
        @lastBuffered += ' + "'
      @lastBufferedType = 'text'
      @lastBuffered += str
      @buf[@lastBufferedIdx - 1] = 'buf.push(' + @bufferStartChar + @lastBuffered + '");'
    else
      @buf.push 'buf.push("' + str + '");'
      @lastBufferedType = 'text'
      @bufferStartChar = '"'
      @lastBuffered = str
      @lastBufferedIdx = @buf.length
    return
  bufferExpression: (src) ->
    if isConstant(src)
      return @buffer(toConstant(src) + '', false)
    if @lastBufferedIdx == @buf.length
      if @lastBufferedType == 'text'
        @lastBuffered += '"'
      @lastBufferedType = 'code'
      @lastBuffered += ' + (' + src + ')'
      @buf[@lastBufferedIdx - 1] = 'buf.push(' + @bufferStartChar + @lastBuffered + ');'
    else
      @buf.push 'buf.push(' + src + ');'
      @lastBufferedType = 'code'
      @bufferStartChar = ''
      @lastBuffered = '(' + src + ')'
      @lastBufferedIdx = @buf.length
    return
  prettyIndent: (offset, newline) ->
    offset = offset or 0
    newline = if newline then '\n' else ''
    @buffer newline + Array(@indents + offset).join(@pp)
    if @parentIndents
      @buf.push 'buf.push.apply(buf, jade_indent);'
    return
  visit: (node) ->
    debug = @debug
    if debug
      @buf.push 'jade_debug.unshift(new jade.DebugItem( ' + node.line + ', ' + (if node.filename then utils.stringify(node.filename) else 'jade_debug[0].filename') + ' ));'
    # Massive hack to fix our context
    # stack for - else[ if] etc
    if false == node.debug and @debug
      @buf.pop()
      @buf.pop()
    @visitNode node
    if debug
      @buf.push 'jade_debug.shift();'
    return
  visitNode: (node) ->
    @['visit' + node.type] node
  visitCase: (node) ->
    _ = @withinCase
    @withinCase = true
    @buf.push 'switch (' + node.expr + '){'
    @visit node.block
    @buf.push '}'
    @withinCase = _
    return
  visitWhen: (node) ->
    if 'default' == node.expr
      @buf.push 'default:'
    else
      @buf.push 'case ' + node.expr + ':'
    if node.block
      @visit node.block
      @buf.push '  break;'
    return
  visitLiteral: (node) ->
    @buffer node.str
    return
  visitBlock: (block) ->
    len = block.nodes.length
    escape = @escape
    pp = @pp
    # Pretty print multi-line text
    if pp and len > 1 and !escape and block.nodes[0].isText and block.nodes[1].isText
      @prettyIndent 1, true
    i = 0
    while i < len
      # Pretty print text
      if pp and i > 0 and !escape and block.nodes[i].isText and block.nodes[i - 1].isText
        @prettyIndent 1, false
      @visit block.nodes[i]
      # Multiple text nodes are separated by newlines
      if block.nodes[i + 1] and block.nodes[i].isText and block.nodes[i + 1].isText
        @buffer '\n'
      ++i
    return
  visitMixinBlock: (block) ->
    if @pp
      @buf.push 'jade_indent.push(\'' + Array(@indents + 1).join(@pp) + '\');'
    @buf.push 'block && block();'
    if @pp
      @buf.push 'jade_indent.pop();'
    return
  visitDoctype: (doctype) ->
    if doctype and (doctype.val or !@doctype)
      @setDoctype doctype.val or 'default'
    if @doctype
      @buffer @doctype
    @hasCompiledDoctype = true
    return
  visitMixin: (mixin) ->
    `var val`
    name = 'jade_mixins['
    args = mixin.args or ''
    block = mixin.block
    attrs = mixin.attrs
    attrsBlocks = mixin.attributeBlocks.slice()
    pp = @pp
    dynamic = mixin.name[0] == '#'
    key = mixin.name
    if dynamic
      @dynamicMixins = true
    name += (if dynamic then mixin.name.substr(2, mixin.name.length - 3) else '"' + mixin.name + '"') + ']'
    @mixins[key] = @mixins[key] or
      used: false
      instances: []
    if mixin.call
      @mixins[key].used = true
      if pp
        @buf.push 'jade_indent.push(\'' + Array(@indents + 1).join(pp) + '\');'
      if block or attrs.length or attrsBlocks.length
        @buf.push name + '.call({'
        if block
          @buf.push 'block: function(){'
          # Render block with no indents, dynamically added when rendered
          @parentIndents++
          _indents = @indents
          @indents = 0
          @visit mixin.block
          @indents = _indents
          @parentIndents--
          if attrs.length or attrsBlocks.length
            @buf.push '},'
          else
            @buf.push '}'
        if attrsBlocks.length
          if attrs.length
            val = @attrs(attrs)
            attrsBlocks.unshift val
          @buf.push 'attributes: jade.merge([' + attrsBlocks.join(',') + '])'
        else if attrs.length
          val = @attrs(attrs)
          @buf.push 'attributes: ' + val
        if args
          @buf.push '}, ' + args + ');'
        else
          @buf.push '});'
      else
        @buf.push name + '(' + args + ');'
      if pp
        @buf.push 'jade_indent.pop();'
    else
      mixin_start = @buf.length
      args = if args then args.split(',') else []
      rest = undefined
      if args.length and /^\.\.\./.test(args[args.length - 1].trim())
        rest = args.pop().trim().replace(/^\.\.\./, '')
      # we need use jade_interp here for v8: https://code.google.com/p/v8/issues/detail?id=4165
      # once fixed, use this: this.buf.push(name + ' = function(' + args.join(',') + '){');
      @buf.push name + ' = jade_interp = function(' + args.join(',') + '){'
      @buf.push 'var block = (this && this.block), attributes = (this && this.attributes) || {};'
      if rest
        @buf.push 'var ' + rest + ' = [];'
        @buf.push 'for (jade_interp = ' + args.length + '; jade_interp < arguments.length; jade_interp++) {'
        @buf.push '  ' + rest + '.push(arguments[jade_interp]);'
        @buf.push '}'
      @parentIndents++
      @visit block
      @parentIndents--
      @buf.push '};'
      mixin_end = @buf.length
      @mixins[key].instances.push
        start: mixin_start
        end: mixin_end
    return
  visitTag: (tag) ->

    bufferName = ->
      if tag.buffer
        self.bufferExpression name
      else
        self.buffer name
      return

    @indents++
    name = tag.name
    pp = @pp
    self = this
    if 'pre' == tag.name
      @escape = true
    if !@hasCompiledTag
      if !@hasCompiledDoctype and 'html' == name
        @visitDoctype()
      @hasCompiledTag = true
    # pretty print
    if pp and !tag.isInline()
      @prettyIndent 0, true
    if tag.selfClosing or !@xml and selfClosing[tag.name]
      @buffer '<'
      bufferName()
      @visitAttributes tag.attrs, tag.attributeBlocks.slice()
      if @terse then @buffer('>') else @buffer('/>')
      # if it is non-empty throw an error
      if tag.block and !(tag.block.type == 'Block' and tag.block.nodes.length == 0) and tag.block.nodes.some(((tag) ->
          tag.type != 'Text' or !/^\s*$/.test(tag.val)
        ))
        throw errorAtNode(tag, new Error(name + ' is self closing and should not have content.'))
    else
      # Optimize attributes buffering
      @buffer '<'
      bufferName()
      @visitAttributes tag.attrs, tag.attributeBlocks.slice()
      @buffer '>'
      if tag.code
        @visitCode tag.code
      @visit tag.block
      # pretty print
      if pp and !tag.isInline() and 'pre' != tag.name and !tag.canInline()
        @prettyIndent 0, true
      @buffer '</'
      bufferName()
      @buffer '>'
    if 'pre' == tag.name
      @escape = false
    @indents--
    return
  visitFilter: (filter) ->
    text = filter.block.nodes.map((node) ->
      node.val
    ).join('\n')
    filter.attrs.filename = @options.filename
    try
      @buffer filters(filter.name, text, filter.attrs), true
    catch err
      throw errorAtNode(filter, err)
    return
  visitText: (text) ->
    @buffer text.val, true
    return
  visitComment: (comment) ->
    if !comment.buffer
      return
    if @pp
      @prettyIndent 1, true
    @buffer '<!--' + comment.val + '-->'
    return
  visitBlockComment: (comment) ->
    if !comment.buffer
      return
    if @pp
      @prettyIndent 1, true
    @buffer '<!--' + comment.val
    @visit comment.block
    if @pp
      @prettyIndent 1, true
    @buffer '-->'
    return
  visitCode: (code) ->
    # Wrap code blocks with {}.
    # we only wrap unbuffered code blocks ATM
    # since they are usually flow control
    # Buffer code
    if code.buffer
      val = code.val.trim()
      val = 'null == (jade_interp = ' + val + ') ? "" : jade_interp'
      if code.escape
        val = 'jade.escape(' + val + ')'
      @bufferExpression val
    else
      @buf.push code.val
    # Block support
    if code.block
      if !code.buffer
        @buf.push '{'
      @visit code.block
      if !code.buffer
        @buf.push '}'
    return
  visitEach: (each) ->
    @buf.push '' + '// iterate ' + each.obj + '\n' + ';(function(){\n' + '  var $$obj = ' + each.obj + ';\n' + '  if (\'number\' == typeof $$obj.length) {\n'
    if each.alternative
      @buf.push '  if ($$obj.length) {'
    @buf.push '' + '    for (var ' + each.key + ' = 0, $$l = $$obj.length; ' + each.key + ' < $$l; ' + each.key + '++) {\n' + '      var ' + each.val + ' = $$obj[' + each.key + '];\n'
    @visit each.block
    @buf.push '    }\n'
    if each.alternative
      @buf.push '  } else {'
      @visit each.alternative
      @buf.push '  }'
    @buf.push '' + '  } else {\n' + '    var $$l = 0;\n' + '    for (var ' + each.key + ' in $$obj) {\n' + '      $$l++;' + '      var ' + each.val + ' = $$obj[' + each.key + '];\n'
    @visit each.block
    @buf.push '    }\n'
    if each.alternative
      @buf.push '    if ($$l === 0) {'
      @visit each.alternative
      @buf.push '    }'
    @buf.push '  }\n}).call(this);\n'
    return
  visitAttributes: (attrs, attributeBlocks) ->
    if attributeBlocks.length
      if attrs.length
        val = @attrs(attrs)
        attributeBlocks.unshift val
      @bufferExpression 'jade.attrs(jade.merge([' + attributeBlocks.join(',') + ']), ' + utils.stringify(@terse) + ')'
    else if attrs.length
      @attrs attrs, true
    return
  attrs: (attrs, buffer) ->
    buf = []
    classes = []
    classEscaping = []
    attrs.forEach ((attr) ->
      `var val`
      key = attr.name
      escaped = attr.escaped
      if key == 'class'
        classes.push attr.val
        classEscaping.push attr.escaped
      else if isConstant(attr.val)
        if buffer
          @buffer runtime.attr(key, toConstant(attr.val), escaped, @terse)
        else
          val = toConstant(attr.val)
          if key == 'style'
            val = runtime.style(val)
          if escaped and !(key.indexOf('data') == 0 and typeof val != 'string')
            val = runtime.escape(val)
          buf.push utils.stringify(key) + ': ' + utils.stringify(val)
      else
        if buffer
          @bufferExpression 'jade.attr("' + key + '", ' + attr.val + ', ' + utils.stringify(escaped) + ', ' + utils.stringify(@terse) + ')'
        else
          val = attr.val
          if key == 'style'
            val = 'jade.style(' + val + ')'
          if escaped and !(key.indexOf('data') == 0)
            val = 'jade.escape(' + val + ')'
          else if escaped
            val = '(typeof (jade_interp = ' + val + ') == "string" ? jade.escape(jade_interp) : jade_interp)'
          buf.push utils.stringify(key) + ': ' + val
      return
    ).bind(this)
    if buffer
      if classes.every(isConstant)
        @buffer runtime.cls(classes.map(toConstant), classEscaping)
      else
        @bufferExpression 'jade.cls([' + classes.join(',') + '], ' + utils.stringify(classEscaping) + ')'
    else if classes.length
      if classes.every(isConstant)
        classes = utils.stringify(runtime.joinClasses(classes.map(toConstant).map(runtime.joinClasses).map((cls, i) ->
          if classEscaping[i] then runtime.escape(cls) else cls
        )))
      else
        classes = '(jade_interp = ' + utils.stringify(classEscaping) + ',' + ' jade.joinClasses([' + classes.join(',') + '].map(jade.joinClasses).map(function (cls, i) {' + '   return jade_interp[i] ? jade.escape(cls) : cls' + ' }))' + ')'
      if classes.length
        buf.push '"class": ' + classes
    '{' + buf.join(',') + '}'
