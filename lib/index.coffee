###*
# Parse the given `str` of jade and return a function body.
#
# @param {String} str
# @param {Object} options
# @return {Object}
# @api private
###

parse = (str, options) ->
  if options.lexer
    console.warn 'Using `lexer` as a local in render() is deprecated and ' + 'will be interpreted as an option in Jade 2.0.0'
  # Parse
  parser = new ((options.parser or Parser))(str, options.filename, options)
  tokens = undefined
  try
    # Parse
    tokens = parser.parse()
  catch err
    parser = parser.context()
    runtime.rethrow err, parser.filename, parser.lexer.lineno, parser.input
  # Compile
  compiler = new ((options.compiler or Compiler))(tokens, options)
  js = undefined
  try
    js = compiler.compile()
  catch err
    if err.line and (err.filename or !options.filename)
      runtime.rethrow err, err.filename, err.line, parser.input
    else
      if err instanceof Error
        err.message += '\n\nPlease report this entire error and stack trace to https://github.com/jadejs/jade/issues'
      throw err
  # Debug compiler
  if options.debug
    console.error '\nCompiled Function:\n\n[90m%s[0m', js.replace(/^/gm, '  ')
  globals = []
  if options.globals
    globals = options.globals.slice()
  globals.push 'jade'
  globals.push 'jade_mixins'
  globals.push 'jade_interp'
  globals.push 'jade_debug'
  globals.push 'buf'
  body = '' + 'var buf = [];\n' + 'var jade_mixins = {};\n' + 'var jade_interp;\n' + (if options.self then 'var self = locals || {};\n' + js else addWith('locals || {}', '\n' + js, globals)) + ';' + 'return buf.join("");'
  {
    body: body
    dependencies: parser.dependencies
  }

###*
# Get the template from a string or a file, either compiled on-the-fly or
# read from cache (if enabled), and cache the template if needed.
#
# If `str` is not set, the file specified in `options.filename` will be read.
#
# If `options.cache` is true, this function reads the file from
# `options.filename` so it must be set prior to calling this function.
#
# @param {Object} options
# @param {String=} str
# @return {Function}
# @api private
###

handleTemplateCache = (options, str) ->
  key = options.filename
  if options.cache and exports.cache[key]
    exports.cache[key]
  else
    if str == undefined
      str = fs.readFileSync(options.filename, 'utf8')
    templ = exports.compile(str, options)
    if options.cache
      exports.cache[key] = templ
    templ

'use strict'

###!
# Jade
# Copyright(c) 2010 TJ Holowaychuk <tj@vision-media.ca>
# MIT Licensed
###

###*
# Module dependencies.
###

Parser = require('./parser')
Lexer = require('./lexer')
Compiler = require('./compiler')
runtime = require('./runtime')
addWith = require('with')
fs = require('fs')
utils = require('./utils')

###*
# Expose self closing tags.
###

# FIXME: either stop exporting selfClosing in v2 or export the new object
# form
exports.selfClosing = Object.keys(require('void-elements'))

###*
# Default supported doctypes.
###

exports.doctypes = require('./doctypes')

###*
# Text filters.
###

exports.filters = require('./filters')

###*
# Utilities.
###

exports.utils = utils

###*
# Expose `Compiler`.
###

exports.Compiler = Compiler

###*
# Expose `Parser`.
###

exports.Parser = Parser

###*
# Expose `Lexer`.
###

exports.Lexer = Lexer

###*
# Nodes.
###

exports.nodes = require('./nodes')

###*
# Jade runtime helpers.
###

exports.runtime = runtime

###*
# Template function cache.
###

exports.cache = {}

###*
# Compile a `Function` representation of the given jade `str`.
#
# Options:
#
#   - `compileDebug` when `false` debugging code is stripped from the compiled
       template, when it is explicitly `true`, the source code is included in
       the compiled template for better accuracy.
#   - `filename` used to improve errors when `compileDebug` is not `false` and to resolve imports/extends
#
# @param {String} str
# @param {Options} options
# @return {Function}
# @api public
###

exports.compile = (str, options) ->
  `var options`
  options = options or {}
  filename = if options.filename then utils.stringify(options.filename) else 'undefined'
  fn = undefined
  str = String(str)
  parsed = parse(str, options)
  if options.compileDebug != false
    fn = [
      'var jade_debug = [ new jade.DebugItem( 1, ' + filename + ' ) ];'
      'try {'
      parsed.body
      '} catch (err) {'
      '  jade.rethrow(err, jade_debug[0].filename, jade_debug[0].lineno' + (if options.compileDebug == true then ',' + utils.stringify(str) else '') + ');'
      '}'
    ].join('\n')
  else
    fn = parsed.body
  fn = new Function('locals, jade', fn)

  res = (locals) ->
    fn locals, Object.create(runtime)

  if options.client

    res.toString = ->
      err = new Error('The `client` option is deprecated, use the `jade.compileClient` method instead')
      err.name = 'Warning'
      console.error err.stack or err.message
      exports.compileClient str, options

  res.dependencies = parsed.dependencies
  res

###*
# Compile a JavaScript source representation of the given jade `str`.
#
# Options:
#
#   - `compileDebug` When it is `true`, the source code is included in
#     the compiled template for better error messages.
#   - `filename` used to improve errors when `compileDebug` is not `true` and to resolve imports/extends
#   - `name` the name of the resulting function (defaults to "template")
#
# @param {String} str
# @param {Options} options
# @return {Object}
# @api public
###

exports.compileClientWithDependenciesTracked = (str, options) ->
  `var options`
  options = options or {}
  name = options.name or 'template'
  filename = if options.filename then utils.stringify(options.filename) else 'undefined'
  fn = undefined
  str = String(str)
  options.compileDebug = if options.compileDebug then true else false
  parsed = parse(str, options)
  if options.compileDebug
    fn = [
      'var jade_debug = [ new jade.DebugItem( 1, ' + filename + ' ) ];'
      'try {'
      parsed.body
      '} catch (err) {'
      '  jade.rethrow(err, jade_debug[0].filename, jade_debug[0].lineno, ' + utils.stringify(str) + ');'
      '}'
    ].join('\n')
  else
    fn = parsed.body
  {
    body: 'function ' + name + '(locals) {\n' + fn + '\n}'
    dependencies: parsed.dependencies
  }

###*
# Compile a JavaScript source representation of the given jade `str`.
#
# Options:
#
#   - `compileDebug` When it is `true`, the source code is included in
#     the compiled template for better error messages.
#   - `filename` used to improve errors when `compileDebug` is not `true` and to resolve imports/extends
#   - `name` the name of the resulting function (defaults to "template")
#
# @param {String} str
# @param {Options} options
# @return {String}
# @api public
###

exports.compileClient = (str, options) ->
  exports.compileClientWithDependenciesTracked(str, options).body

###*
# Compile a `Function` representation of the given jade file.
#
# Options:
#
#   - `compileDebug` when `false` debugging code is stripped from the compiled
       template, when it is explicitly `true`, the source code is included in
       the compiled template for better accuracy.
#
# @param {String} path
# @param {Options} options
# @return {Function}
# @api public
###

exports.compileFile = (path, options) ->
  options = options or {}
  options.filename = path
  handleTemplateCache options

###*
# Render the given `str` of jade.
#
# Options:
#
#   - `cache` enable template caching
#   - `filename` filename required for `include` / `extends` and caching
#
# @param {String} str
# @param {Object|Function} options or fn
# @param {Function|undefined} fn
# @returns {String}
# @api public
###

exports.render = (str, options, fn) ->
  # support callback API
  if 'function' == typeof options
    fn = options
    options = undefined
  if typeof fn == 'function'
    res = undefined
    try
      res = exports.render(str, options)
    catch ex
      return fn(ex)
    return fn(null, res)
  options = options or {}
  # cache requires .filename
  if options.cache and !options.filename
    throw new Error('the "filename" option is required for caching')
  handleTemplateCache(options, str) options

###*
# Render a Jade file at the given `path`.
#
# @param {String} path
# @param {Object|Function} options or callback
# @param {Function|undefined} fn
# @returns {String}
# @api public
###

exports.renderFile = (path, options, fn) ->
  # support callback API
  if 'function' == typeof options
    fn = options
    options = undefined
  if typeof fn == 'function'
    res = undefined
    try
      res = exports.renderFile(path, options)
    catch ex
      return fn(ex)
    return fn(null, res)
  options = options or {}
  options.filename = path
  handleTemplateCache(options) options

###*
# Compile a Jade file at the given `path` for use on the client.
#
# @param {String} path
# @param {Object} options
# @returns {String}
# @api public
###

exports.compileFileClient = (path, options) ->
  key = path + ':client'
  options = options or {}
  options.filename = path
  if options.cache and exports.cache[key]
    return exports.cache[key]
  str = fs.readFileSync(options.filename, 'utf8')
  out = exports.compileClient(str, options)
  if options.cache
    exports.cache[key] = out
  out

###*
# Express support.
###

exports.__express = (path, options, fn) ->
  if options.compileDebug == undefined and process.env.NODE_ENV == 'production'
    options.compileDebug = false
  exports.renderFile path, options, fn
  return
