'use strict'
Lexer = require('./lexer')
nodes = require('./nodes')
utils = require('./utils')
filters = require('./filters')
path = require('path')
constantinople = require('constantinople')
parseJSExpression = require('character-parser').parseMax
extname = path.extname

###*
# Initialize `Parser` with the given input `str` and `filename`.
#
# @param {String} str
# @param {String} filename
# @param {Object} options
# @api public
###

Parser = exports =
module.exports = (str, filename, options) ->
  #Strip any UTF-8 BOM off of the start of `str`, if it exists.
  @input = str.replace(/^\uFEFF/, '')
  @lexer = new Lexer(@input, filename)
  @filename = filename
  @blocks = {}
  @mixins = {}
  @options = options
  @contexts = [ this ]
  @inMixin = 0
  @dependencies = []
  @inBlock = 0
  return

###*
# Parser prototype.
###

Parser.prototype =
  constructor: Parser
  context: (parser) ->
    if parser
      @contexts.push parser
    else
      return @contexts.pop()
    return
  advance: ->
    @lexer.advance()
  peek: ->
    @lookahead 1
  line: ->
    @lexer.lineno
  lookahead: (n) ->
    @lexer.lookahead n
  parse: ->
    block = new (nodes.Block)
    parser = undefined
    block.line = 0
    block.filename = @filename
    while 'eos' != @peek().type
      if 'newline' == @peek().type
        @advance()
      else
        next = @peek()
        expr = @parseExpr()
        expr.filename = expr.filename or @filename
        expr.line = next.line
        block.push expr
    if parser = @extending
      @context parser
      ast = parser.parse()
      @context()
      # hoist mixins
      for name of @mixins
        ast.unshift @mixins[name]
      return ast
    if !@extending and !@included and Object.keys(@blocks).length
      blocks = []
      utils.walkAST block, (node) ->
        if node.type == 'Block' and node.name
          blocks.push node.name
        return
      Object.keys(@blocks).forEach ((name) ->
        if blocks.indexOf(name) == -1 and !@blocks[name].isSubBlock
          console.warn 'Warning: Unexpected block "' + name + '" ' + ' on line ' + @blocks[name].line + ' of ' + @blocks[name].filename + '. This block is never used. This warning will be an error in v2.0.0'
        return
      ).bind(this)
    block
  expect: (type) ->
    if @peek().type == type
      return @advance()
    else
      throw new Error('expected "' + type + '", but got "' + @peek().type + '"')
    return
  accept: (type) ->
    if @peek().type == type
      return @advance()
    return
  parseExpr: ->
    switch @peek().type
      when 'tag'
        return @parseTag()
      when 'mixin'
        return @parseMixin()
      when 'block'
        return @parseBlock()
      when 'mixin-block'
        return @parseMixinBlock()
      when 'case'
        return @parseCase()
      when 'extends'
        return @parseExtends()
      when 'include'
        return @parseInclude()
      when 'doctype'
        return @parseDoctype()
      when 'filter'
        return @parseFilter()
      when 'comment'
        return @parseComment()
      when 'text'
        return @parseText()
      when 'each'
        return @parseEach()
      when 'code'
        return @parseCode()
      when 'blockCode'
        return @parseBlockCode()
      when 'call'
        return @parseCall()
      when 'interpolation'
        return @parseInterpolation()
      when 'yield'
        @advance()
        block = new (nodes.Block)
        block.yield = true
        return block
      when 'id', 'class'
        tok = @advance()
        @lexer.defer @lexer.tok('tag', 'div')
        @lexer.defer tok
        return @parseExpr()
      else
        throw new Error('unexpected token "' + @peek().type + '"')
    return
  parseText: ->
    tok = @expect('text')
    tokens = @parseInlineTagsInText(tok.val)
    if tokens.length == 1
      return tokens[0]
    node = new (nodes.Block)
    i = 0
    while i < tokens.length
      node.push tokens[i]
      i++
    node
  parseBlockExpansion: ->
    if ':' == @peek().type
      @advance()
      new (nodes.Block)(@parseExpr())
    else
      @block()
  parseCase: ->
    val = @expect('case').val
    node = new (nodes.Case)(val)
    node.line = @line()
    block = new (nodes.Block)
    block.line = @line()
    block.filename = @filename
    @expect 'indent'
    while 'outdent' != @peek().type
      switch @peek().type
        when 'comment', 'newline'
          @advance()
        when 'when'
          block.push @parseWhen()
        when 'default'
          block.push @parseDefault()
        else
          throw new Error('Unexpected token "' + @peek().type + '", expected "when", "default" or "newline"')
    @expect 'outdent'
    node.block = block
    node
  parseWhen: ->
    val = @expect('when').val
    if @peek().type != 'newline'
      new (nodes.Case.When)(val, @parseBlockExpansion())
    else
      new (nodes.Case.When)(val)
  parseDefault: ->
    @expect 'default'
    new (nodes.Case.When)('default', @parseBlockExpansion())
  parseCode: (afterIf) ->
    tok = @expect('code')
    node = new (nodes.Code)(tok.val, tok.buffer, tok.escape)
    block = undefined
    node.line = @line()
    # throw an error if an else does not have an if
    if tok.isElse and !tok.hasIf
      throw new Error('Unexpected else without if')
    # handle block
    block = 'indent' == @peek().type
    if block
      node.block = @block()
    # handle missing block
    if tok.requiresBlock and !block
      node.block = new (nodes.Block)
    # mark presense of if for future elses
    if tok.isIf and @peek().isElse
      @peek().hasIf = true
    else if tok.isIf and @peek().type == 'newline' and @lookahead(2).isElse
      @lookahead(2).hasIf = true
    node
  parseBlockCode: ->
    tok = @expect('blockCode')
    node = undefined
    body = @peek()
    text = undefined
    if body.type == 'pipeless-text'
      @advance()
      text = body.val.join('\n')
    else
      text = ''
    node = new (nodes.Code)(text, false, false)
    node
  parseComment: ->
    tok = @expect('comment')
    node = undefined
    block = undefined
    if block = @parseTextBlock()
      node = new (nodes.BlockComment)(tok.val, block, tok.buffer)
    else
      node = new (nodes.Comment)(tok.val, tok.buffer)
    node.line = @line()
    node
  parseDoctype: ->
    tok = @expect('doctype')
    node = new (nodes.Doctype)(tok.val)
    node.line = @line()
    node
  parseFilter: ->
    tok = @expect('filter')
    attrs = @accept('attrs')
    block = undefined
    block = @parseTextBlock() or new (nodes.Block)
    options = {}
    if attrs
      attrs.attrs.forEach (attribute) ->
        options[attribute.name] = constantinople.toConstant(attribute.val)
        return
    node = new (nodes.Filter)(tok.val, block, options)
    node.line = @line()
    node
  parseEach: ->
    tok = @expect('each')
    node = new (nodes.Each)(tok.code, tok.val, tok.key)
    node.line = @line()
    node.block = @block()
    if @peek().type == 'code' and @peek().val == 'else'
      @advance()
      node.alternative = @block()
    node
  resolvePath: (path, purpose) ->
    p = require('path')
    dirname = p.dirname
    basename = p.basename
    join = p.join
    if path[0] != '/' and !@filename
      throw new Error('the "filename" option is required to use "' + purpose + '" with "relative" paths')
    if path[0] == '/' and !@options.basedir
      throw new Error('the "basedir" option is required to use "' + purpose + '" with "absolute" paths')
    path = join(if path[0] == '/' then @options.basedir else dirname(@filename), path)
    if basename(path).indexOf('.') == -1
      path += '.jade'
    path
  parseExtends: ->
    `var path`
    fs = require('fs')
    path = @resolvePath(@expect('extends').val.trim(), 'extends')
    if '.jade' != path.substr(-5)
      path += '.jade'
    @dependencies.push path
    str = fs.readFileSync(path, 'utf8')
    parser = new (@constructor)(str, path, @options)
    parser.dependencies = @dependencies
    parser.blocks = @blocks
    parser.included = @included
    parser.contexts = @contexts
    @extending = parser
    # TODO: null node
    new (nodes.Literal)('')
  parseBlock: ->
    block = @expect('block')
    mode = block.mode
    name = block.val.trim()
    line = block.line
    @inBlock++
    block = if 'indent' == @peek().type then @block() else new (nodes.Block)(new (nodes.Literal)(''))
    @inBlock--
    block.name = name
    block.line = line
    prev = @blocks[name] or
      prepended: []
      appended: []
    if prev.mode == 'replace'
      return @blocks[name] = prev
    allNodes = prev.prepended.concat(block.nodes).concat(prev.appended)
    switch mode
      when 'append'
        prev.appended = if prev.parser == this then prev.appended.concat(block.nodes) else block.nodes.concat(prev.appended)
      when 'prepend'
        prev.prepended = if prev.parser == this then block.nodes.concat(prev.prepended) else prev.prepended.concat(block.nodes)
    block.nodes = allNodes
    block.appended = prev.appended
    block.prepended = prev.prepended
    block.mode = mode
    block.parser = this
    block.isSubBlock = @inBlock > 0
    @blocks[name] = block
  parseMixinBlock: ->
    block = @expect('mixin-block')
    if !@inMixin
      throw new Error('Anonymous blocks are not allowed unless they are part of a mixin.')
    new (nodes.MixinBlock)
  parseInclude: ->
    `var path`
    `var str`
    `var str`
    fs = require('fs')
    tok = @expect('include')
    path = @resolvePath(tok.val.trim(), 'include')
    @dependencies.push path
    # has-filter
    if tok.filter
      str = fs.readFileSync(path, 'utf8').replace(/\r/g, '')
      options = filename: path
      if tok.attrs
        tok.attrs.attrs.forEach (attribute) ->
          options[attribute.name] = constantinople.toConstant(attribute.val)
          return
      str = filters(tok.filter, str, options)
      return new (nodes.Literal)(str)
    # non-jade
    if '.jade' != path.substr(-5)
      str = fs.readFileSync(path, 'utf8').replace(/\r/g, '')
      return new (nodes.Literal)(str)
    str = fs.readFileSync(path, 'utf8')
    parser = new (@constructor)(str, path, @options)
    parser.dependencies = @dependencies
    parser.blocks = utils.merge({}, @blocks)
    parser.included = true
    parser.mixins = @mixins
    @context parser
    ast = parser.parse()
    @context()
    ast.filename = path
    if 'indent' == @peek().type
      ast.includeBlock().push @block()
    ast
  parseCall: ->
    tok = @expect('call')
    name = tok.val
    args = tok.args
    mixin = new (nodes.Mixin)(name, args, new (nodes.Block), true)
    @tag mixin
    if mixin.code
      mixin.block.push mixin.code
      mixin.code = null
    if mixin.block.isEmpty()
      mixin.block = null
    mixin
  parseMixin: ->
    tok = @expect('mixin')
    name = tok.val
    args = tok.args
    mixin = undefined
    # definition
    if 'indent' == @peek().type
      @inMixin++
      mixin = new (nodes.Mixin)(name, args, @block(), false)
      @mixins[name] = mixin
      @inMixin--
      mixin
      # call
    else
      new (nodes.Mixin)(name, args, null, true)
  parseInlineTagsInText: (str) ->
    `var text`
    `var rest`
    `var text`
    line = @line()
    match = /(\\)?#\[((?:.|\n)*)$/.exec(str)
    if match
      if match[1]
        # escape
        text = new (nodes.Text)(str.substr(0, match.index) + '#[')
        text.line = line
        rest = @parseInlineTagsInText(match[2])
        if rest[0].type == 'Text'
          text.val += rest[0].val
          rest.shift()
        [ text ].concat rest
      else
        text = new (nodes.Text)(str.substr(0, match.index))
        text.line = line
        buffer = [ text ]
        rest = match[2]
        range = parseJSExpression(rest)
        inner = new Parser(range.src, @filename, @options)
        buffer.push inner.parse()
        buffer.concat @parseInlineTagsInText(rest.substr(range.end + 1))
    else
      text = new (nodes.Text)(str)
      text.line = line
      [ text ]
  parseTextBlock: ->
    block = new (nodes.Block)
    block.line = @line()
    body = @peek()
    if body.type != 'pipeless-text'
      return
    @advance()
    block.nodes = body.val.reduce(((accumulator, text) ->
      accumulator.concat @parseInlineTagsInText(text)
    ).bind(this), [])
    block
  block: ->
    block = new (nodes.Block)
    block.line = @line()
    block.filename = @filename
    @expect 'indent'
    while 'outdent' != @peek().type
      if 'newline' == @peek().type
        @advance()
      else
        expr = @parseExpr()
        expr.filename = @filename
        block.push expr
    @expect 'outdent'
    block
  parseInterpolation: ->
    tok = @advance()
    tag = new (nodes.Tag)(tok.val)
    tag.buffer = true
    @tag tag
  parseTag: ->
    tok = @advance()
    tag = new (nodes.Tag)(tok.val)
    tag.selfClosing = tok.selfClosing
    @tag tag
  tag: (tag) ->
    tag.line = @line()
    seenAttrs = false
    # (attrs | class | id)*

    ###*out:
      while (true) {
        switch (this.peek().type) {
          case 'id':
          case 'class':
            var tok = this.advance();
            tag.setAttribute(tok.type, "'" + tok.val + "'");
            continue;
          case 'attrs':
            if (seenAttrs) {
              console.warn(this.filename + ', line ' + this.peek().line + ':\nYou should not have jade tags with multiple attributes.');
            }
            seenAttrs = true;
            var tok = this.advance();
            var attrs = tok.attrs;

            if (tok.selfClosing) tag.selfClosing = true;

            for (var i = 0; i < attrs.length; i++) {
              tag.setAttribute(attrs[i].name, attrs[i].val, attrs[i].escaped);
            }
            continue;
          case '&attributes':
            var tok = this.advance();
            tag.addAttributes(tok.val);
            break;
          default:
            break out;
        }
      }
    ###

    # check immediate '.'
    if 'dot' == @peek().type
      tag.textOnly = true
      @advance()
    # (text | code | ':')?
    switch @peek().type
      when 'text'
        tag.block.push @parseText()
      when 'code'
        tag.code = @parseCode()
      when ':'
        @advance()
        tag.block = new (nodes.Block)
        tag.block.push @parseExpr()
      when 'newline', 'indent', 'outdent', 'eos', 'pipeless-text'
      else
        throw new Error('Unexpected token `' + @peek().type + '` expected `text`, `code`, `:`, `newline` or `eos`')
    # newline*
    while 'newline' == @peek().type
      @advance()
    # block?
    if tag.textOnly
      tag.block = @parseTextBlock() or new (nodes.Block)
    else if 'indent' == @peek().type
      block = @block()
      i = 0
      len = block.nodes.length
      while i < len
        tag.block.push block.nodes[i]
        ++i
    tag
