'use strict'
Node = require('./node')

###*
# Initialize a `Attrs` node.
#
# @api public
###

Attrs = 
module.exports = ->
  @attributeNames = []
  @attrs = []
  @attributeBlocks = []
  return

# Inherit from `Node`.
Attrs.prototype = Object.create(Node.prototype)
Attrs::constructor = Attrs
Attrs::type = 'Attrs'

###*
# Set attribute `name` to `val`, keep in mind these become
# part of a raw js object literal, so to quote a value you must
# '"quote me"', otherwise or example 'user.name' is literal JavaScript.
#
# @param {String} name
# @param {String} val
# @param {Boolean} escaped
# @return {Tag} for chaining
# @api public
###

Attrs::setAttribute = (name, val, escaped) ->
  if name != 'class' and @attributeNames.indexOf(name) != -1
    throw new Error('Duplicate attribute "' + name + '" is not allowed.')
  @attributeNames.push name
  @attrs.push
    name: name
    val: val
    escaped: escaped
  this

###*
# Remove attribute `name` when present.
#
# @param {String} name
# @api public
###

Attrs::removeAttribute = (name) ->
  err = new Error('attrs.removeAttribute is deprecated and will be removed in v2.0.0')
  console.warn err.stack
  i = 0
  len = @attrs.length
  while i < len
    if @attrs[i] and @attrs[i].name == name
      delete @attrs[i]
    ++i
  return

###*
# Get attribute value by `name`.
#
# @param {String} name
# @return {String}
# @api public
###

Attrs::getAttribute = (name) ->
  err = new Error('attrs.getAttribute is deprecated and will be removed in v2.0.0')
  console.warn err.stack
  i = 0
  len = @attrs.length
  while i < len
    if @attrs[i] and @attrs[i].name == name
      return @attrs[i].val
    ++i
  return

Attrs::addAttributes = (src) ->
  @attributeBlocks.push src
  return
