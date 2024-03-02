'use strict';
var Lexer, Parser, constantinople, exports, extname, filters, nodes, parseJSExpression, path, utils;

Lexer = require('./lexer');

nodes = require('./nodes');

utils = require('./utils');

filters = require('./filters');

path = require('path');

constantinople = require('constantinople');

parseJSExpression = require('character-parser').parseMax;

extname = path.extname;


/**
 * Initialize `Parser` with the given input `str` and `filename`.
 *
 * @param {String} str
 * @param {String} filename
 * @param {Object} options
 * @api public
 */

Parser = exports = module.exports = function(str, filename, options) {
  this.input = str.replace(/^\uFEFF/, '');
  this.lexer = new Lexer(this.input, filename);
  this.filename = filename;
  this.blocks = {};
  this.mixins = {};
  this.options = options;
  this.contexts = [this];
  this.inMixin = 0;
  this.dependencies = [];
  this.inBlock = 0;
};


/**
 * Parser prototype.
 */

Parser.prototype = {
  constructor: Parser,
  context: function(parser) {
    if (parser) {
      this.contexts.push(parser);
    } else {
      return this.contexts.pop();
    }
  },
  advance: function() {
    return this.lexer.advance();
  },
  peek: function() {
    return this.lookahead(1);
  },
  line: function() {
    return this.lexer.lineno;
  },
  lookahead: function(n) {
    return this.lexer.lookahead(n);
  },
  parse: function() {
    var ast, block, blocks, expr, name, next, parser;
    block = new nodes.Block;
    parser = void 0;
    block.line = 0;
    block.filename = this.filename;
    while ('eos' !== this.peek().type) {
      if ('newline' === this.peek().type) {
        this.advance();
      } else {
        next = this.peek();
        expr = this.parseExpr();
        expr.filename = expr.filename || this.filename;
        expr.line = next.line;
        block.push(expr);
      }
    }
    if (parser = this.extending) {
      this.context(parser);
      ast = parser.parse();
      this.context();
      for (name in this.mixins) {
        ast.unshift(this.mixins[name]);
      }
      return ast;
    }
    if (!this.extending && !this.included && Object.keys(this.blocks).length) {
      blocks = [];
      utils.walkAST(block, function(node) {
        if (node.type === 'Block' && node.name) {
          blocks.push(node.name);
        }
      });
      Object.keys(this.blocks).forEach((function(name) {
        if (blocks.indexOf(name) === -1 && !this.blocks[name].isSubBlock) {
          console.warn('Warning: Unexpected block "' + name + '" ' + ' on line ' + this.blocks[name].line + ' of ' + this.blocks[name].filename + '. This block is never used. This warning will be an error in v2.0.0');
        }
      }).bind(this));
    }
    return block;
  },
  expect: function(type) {
    if (this.peek().type === type) {
      return this.advance();
    } else {
      throw new Error('expected "' + type + '", but got "' + this.peek().type + '"');
    }
  },
  accept: function(type) {
    if (this.peek().type === type) {
      return this.advance();
    }
  },
  parseExpr: function() {
    var block, tok;
    switch (this.peek().type) {
      case 'tag':
        return this.parseTag();
      case 'mixin':
        return this.parseMixin();
      case 'block':
        return this.parseBlock();
      case 'mixin-block':
        return this.parseMixinBlock();
      case 'case':
        return this.parseCase();
      case 'extends':
        return this.parseExtends();
      case 'include':
        return this.parseInclude();
      case 'doctype':
        return this.parseDoctype();
      case 'filter':
        return this.parseFilter();
      case 'comment':
        return this.parseComment();
      case 'text':
        return this.parseText();
      case 'each':
        return this.parseEach();
      case 'code':
        return this.parseCode();
      case 'blockCode':
        return this.parseBlockCode();
      case 'call':
        return this.parseCall();
      case 'interpolation':
        return this.parseInterpolation();
      case 'yield':
        this.advance();
        block = new nodes.Block;
        block["yield"] = true;
        return block;
      case 'id':
      case 'class':
        tok = this.advance();
        this.lexer.defer(this.lexer.tok('tag', 'div'));
        this.lexer.defer(tok);
        return this.parseExpr();
      default:
        throw new Error('unexpected token "' + this.peek().type + '"');
    }
  },
  parseText: function() {
    var i, node, tok, tokens;
    tok = this.expect('text');
    tokens = this.parseInlineTagsInText(tok.val);
    if (tokens.length === 1) {
      return tokens[0];
    }
    node = new nodes.Block;
    i = 0;
    while (i < tokens.length) {
      node.push(tokens[i]);
      i++;
    }
    return node;
  },
  parseBlockExpansion: function() {
    if (':' === this.peek().type) {
      this.advance();
      return new nodes.Block(this.parseExpr());
    } else {
      return this.block();
    }
  },
  parseCase: function() {
    var block, node, val;
    val = this.expect('case').val;
    node = new nodes.Case(val);
    node.line = this.line();
    block = new nodes.Block;
    block.line = this.line();
    block.filename = this.filename;
    this.expect('indent');
    while ('outdent' !== this.peek().type) {
      switch (this.peek().type) {
        case 'comment':
        case 'newline':
          this.advance();
          break;
        case 'when':
          block.push(this.parseWhen());
          break;
        case 'default':
          block.push(this.parseDefault());
          break;
        default:
          throw new Error('Unexpected token "' + this.peek().type + '", expected "when", "default" or "newline"');
      }
    }
    this.expect('outdent');
    node.block = block;
    return node;
  },
  parseWhen: function() {
    var val;
    val = this.expect('when').val;
    if (this.peek().type !== 'newline') {
      return new nodes.Case.When(val, this.parseBlockExpansion());
    } else {
      return new nodes.Case.When(val);
    }
  },
  parseDefault: function() {
    this.expect('default');
    return new nodes.Case.When('default', this.parseBlockExpansion());
  },
  parseCode: function(afterIf) {
    var block, node, tok;
    tok = this.expect('code');
    node = new nodes.Code(tok.val, tok.buffer, tok.escape);
    block = void 0;
    node.line = this.line();
    if (tok.isElse && !tok.hasIf) {
      throw new Error('Unexpected else without if');
    }
    block = 'indent' === this.peek().type;
    if (block) {
      node.block = this.block();
    }
    if (tok.requiresBlock && !block) {
      node.block = new nodes.Block;
    }
    if (tok.isIf && this.peek().isElse) {
      this.peek().hasIf = true;
    } else if (tok.isIf && this.peek().type === 'newline' && this.lookahead(2).isElse) {
      this.lookahead(2).hasIf = true;
    }
    return node;
  },
  parseBlockCode: function() {
    var body, node, text, tok;
    tok = this.expect('blockCode');
    node = void 0;
    body = this.peek();
    text = void 0;
    if (body.type === 'pipeless-text') {
      this.advance();
      text = body.val.join('\n');
    } else {
      text = '';
    }
    node = new nodes.Code(text, false, false);
    return node;
  },
  parseComment: function() {
    var block, node, tok;
    tok = this.expect('comment');
    node = void 0;
    block = void 0;
    if (block = this.parseTextBlock()) {
      node = new nodes.BlockComment(tok.val, block, tok.buffer);
    } else {
      node = new nodes.Comment(tok.val, tok.buffer);
    }
    node.line = this.line();
    return node;
  },
  parseDoctype: function() {
    var node, tok;
    tok = this.expect('doctype');
    node = new nodes.Doctype(tok.val);
    node.line = this.line();
    return node;
  },
  parseFilter: function() {
    var attrs, block, node, options, tok;
    tok = this.expect('filter');
    attrs = this.accept('attrs');
    block = void 0;
    block = this.parseTextBlock() || new nodes.Block;
    options = {};
    if (attrs) {
      attrs.attrs.forEach(function(attribute) {
        options[attribute.name] = constantinople.toConstant(attribute.val);
      });
    }
    node = new nodes.Filter(tok.val, block, options);
    node.line = this.line();
    return node;
  },
  parseEach: function() {
    var node, tok;
    tok = this.expect('each');
    node = new nodes.Each(tok.code, tok.val, tok.key);
    node.line = this.line();
    node.block = this.block();
    if (this.peek().type === 'code' && this.peek().val === 'else') {
      this.advance();
      node.alternative = this.block();
    }
    return node;
  },
  resolvePath: function(path, purpose) {
    var basename, dirname, join, p;
    p = require('path');
    dirname = p.dirname;
    basename = p.basename;
    join = p.join;
    if (path[0] !== '/' && !this.filename) {
      throw new Error('the "filename" option is required to use "' + purpose + '" with "relative" paths');
    }
    if (path[0] === '/' && !this.options.basedir) {
      throw new Error('the "basedir" option is required to use "' + purpose + '" with "absolute" paths');
    }
    path = join((path[0] === '/' ? this.options.basedir : dirname(this.filename)), path);
    if (basename(path).indexOf('.') === -1) {
      path += '.jade';
    }
    return path;
  },
  parseExtends: function() {
    var path;
    var fs, parser, str;
    fs = require('fs');
    path = this.resolvePath(this.expect('extends').val.trim(), 'extends');
    if ('.jade' !== path.substr(-5)) {
      path += '.jade';
    }
    this.dependencies.push(path);
    str = fs.readFileSync(path, 'utf8');
    parser = new this.constructor(str, path, this.options);
    parser.dependencies = this.dependencies;
    parser.blocks = this.blocks;
    parser.included = this.included;
    parser.contexts = this.contexts;
    this.extending = parser;
    return new nodes.Literal('');
  },
  parseBlock: function() {
    var allNodes, block, line, mode, name, prev;
    block = this.expect('block');
    mode = block.mode;
    name = block.val.trim();
    line = block.line;
    this.inBlock++;
    block = 'indent' === this.peek().type ? this.block() : new nodes.Block(new nodes.Literal(''));
    this.inBlock--;
    block.name = name;
    block.line = line;
    prev = this.blocks[name] || {
      prepended: [],
      appended: []
    };
    if (prev.mode === 'replace') {
      return this.blocks[name] = prev;
    }
    allNodes = prev.prepended.concat(block.nodes).concat(prev.appended);
    switch (mode) {
      case 'append':
        prev.appended = prev.parser === this ? prev.appended.concat(block.nodes) : block.nodes.concat(prev.appended);
        break;
      case 'prepend':
        prev.prepended = prev.parser === this ? block.nodes.concat(prev.prepended) : prev.prepended.concat(block.nodes);
    }
    block.nodes = allNodes;
    block.appended = prev.appended;
    block.prepended = prev.prepended;
    block.mode = mode;
    block.parser = this;
    block.isSubBlock = this.inBlock > 0;
    return this.blocks[name] = block;
  },
  parseMixinBlock: function() {
    var block;
    block = this.expect('mixin-block');
    if (!this.inMixin) {
      throw new Error('Anonymous blocks are not allowed unless they are part of a mixin.');
    }
    return new nodes.MixinBlock;
  },
  parseInclude: function() {
    var path;
    var str;
    var str;
    var ast, fs, options, parser, str, tok;
    fs = require('fs');
    tok = this.expect('include');
    path = this.resolvePath(tok.val.trim(), 'include');
    this.dependencies.push(path);
    if (tok.filter) {
      str = fs.readFileSync(path, 'utf8').replace(/\r/g, '');
      options = {
        filename: path
      };
      if (tok.attrs) {
        tok.attrs.attrs.forEach(function(attribute) {
          options[attribute.name] = constantinople.toConstant(attribute.val);
        });
      }
      str = filters(tok.filter, str, options);
      return new nodes.Literal(str);
    }
    if ('.jade' !== path.substr(-5)) {
      str = fs.readFileSync(path, 'utf8').replace(/\r/g, '');
      return new nodes.Literal(str);
    }
    str = fs.readFileSync(path, 'utf8');
    parser = new this.constructor(str, path, this.options);
    parser.dependencies = this.dependencies;
    parser.blocks = utils.merge({}, this.blocks);
    parser.included = true;
    parser.mixins = this.mixins;
    this.context(parser);
    ast = parser.parse();
    this.context();
    ast.filename = path;
    if ('indent' === this.peek().type) {
      ast.includeBlock().push(this.block());
    }
    return ast;
  },
  parseCall: function() {
    var args, mixin, name, tok;
    tok = this.expect('call');
    name = tok.val;
    args = tok.args;
    mixin = new nodes.Mixin(name, args, new nodes.Block, true);
    this.tag(mixin);
    if (mixin.code) {
      mixin.block.push(mixin.code);
      mixin.code = null;
    }
    if (mixin.block.isEmpty()) {
      mixin.block = null;
    }
    return mixin;
  },
  parseMixin: function() {
    var args, mixin, name, tok;
    tok = this.expect('mixin');
    name = tok.val;
    args = tok.args;
    mixin = void 0;
    if ('indent' === this.peek().type) {
      this.inMixin++;
      mixin = new nodes.Mixin(name, args, this.block(), false);
      this.mixins[name] = mixin;
      this.inMixin--;
      return mixin;
    } else {
      return new nodes.Mixin(name, args, null, true);
    }
  },
  parseInlineTagsInText: function(str) {
    var text;
    var rest;
    var text;
    var buffer, inner, line, match, range, rest, text;
    line = this.line();
    match = /(\\)?#\[((?:.|\n)*)$/.exec(str);
    if (match) {
      if (match[1]) {
        text = new nodes.Text(str.substr(0, match.index) + '#[');
        text.line = line;
        rest = this.parseInlineTagsInText(match[2]);
        if (rest[0].type === 'Text') {
          text.val += rest[0].val;
          rest.shift();
        }
        return [text].concat(rest);
      } else {
        text = new nodes.Text(str.substr(0, match.index));
        text.line = line;
        buffer = [text];
        rest = match[2];
        range = parseJSExpression(rest);
        inner = new Parser(range.src, this.filename, this.options);
        buffer.push(inner.parse());
        return buffer.concat(this.parseInlineTagsInText(rest.substr(range.end + 1)));
      }
    } else {
      text = new nodes.Text(str);
      text.line = line;
      return [text];
    }
  },
  parseTextBlock: function() {
    var block, body;
    block = new nodes.Block;
    block.line = this.line();
    body = this.peek();
    if (body.type !== 'pipeless-text') {
      return;
    }
    this.advance();
    block.nodes = body.val.reduce((function(accumulator, text) {
      return accumulator.concat(this.parseInlineTagsInText(text));
    }).bind(this), []);
    return block;
  },
  block: function() {
    var block, expr;
    block = new nodes.Block;
    block.line = this.line();
    block.filename = this.filename;
    this.expect('indent');
    while ('outdent' !== this.peek().type) {
      if ('newline' === this.peek().type) {
        this.advance();
      } else {
        expr = this.parseExpr();
        expr.filename = this.filename;
        block.push(expr);
      }
    }
    this.expect('outdent');
    return block;
  },
  parseInterpolation: function() {
    var tag, tok;
    tok = this.advance();
    tag = new nodes.Tag(tok.val);
    tag.buffer = true;
    return this.tag(tag);
  },
  parseTag: function() {
    var tag, tok;
    tok = this.advance();
    tag = new nodes.Tag(tok.val);
    tag.selfClosing = tok.selfClosing;
    return this.tag(tag);
  },
  tag: function(tag) {
    var block, i, len, seenAttrs;
    tag.line = this.line();
    seenAttrs = false;
    ({
      out: function() {
        var __, attrs, i, j, len1, results, tok;
        results = [];
        while (true) {
          switch (this.peek().type) {
            case 'class':
              tok = this.advance();
              tag.setAttribute(tok.type, "'" + tok.val + "'");
              continue;
            case 'attrs':
              if (seenAttrs) {
                console.warn(this.filename + ', line ' + this.peek().line + ':\nYou should not have jade tags with multiple attributes.');
              }
              seenAttrs = true;
              tok = this.advance();
              attrs = tok.attrs;
              if (tok.selfClosing) {
                tag.selfClosing = true;
              }
              i = 0;
              for (i = j = 0, len1 = attrs.length; j < len1; i = ++j) {
                __ = attrs[i];
                tag.setAttribute(attrs[i].name, attrs[i].val, attrs[i].escaped);
                ++i;
              }
              continue;
            case '&attributes':
              tok = this.advance();
              results.push(tag.addAttributes(tok.val));
              break;
            default:
              break;
          }
        }
        return results;
      }
    });
    if ('dot' === this.peek().type) {
      tag.textOnly = true;
      this.advance();
    }
    switch (this.peek().type) {
      case 'text':
        tag.block.push(this.parseText());
        break;
      case 'code':
        tag.code = this.parseCode();
        break;
      case ':':
        this.advance();
        tag.block = new nodes.Block;
        tag.block.push(this.parseExpr());
        break;
      case 'newline':
      case 'indent':
      case 'outdent':
      case 'eos':
      case 'pipeless-text':
        break;
      default:
        throw new Error('Unexpected token `' + this.peek().type + '` expected `text`, `code`, `:`, `newline` or `eos`');
    }
    while ('newline' === this.peek().type) {
      this.advance();
    }
    if (tag.textOnly) {
      tag.block = this.parseTextBlock() || new nodes.Block;
    } else if ('indent' === this.peek().type) {
      block = this.block();
      i = 0;
      len = block.nodes.length;
      while (i < len) {
        tag.block.push(block.nodes[i]);
        ++i;
      }
    }
    return tag;
  }
};
