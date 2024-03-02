'use strict'
Attrs = require('./attrs')
Block = require('./block')
inlineTags = require('../inline-tags')

###*
# Initialize a `Tag` node with the given tag `name` and optional `block`.
#
# @param {String} name
# @param {Block} block
# @api public
###

Tag = 
module.exports = (name, block) ->
  Attrs.call this
  @name = name
  @block = block or new Block
  return

# Inherit from `Attrs`.
Tag.prototype = Object.create(Attrs.prototype)
Tag::constructor = Tag
Tag::type = 'Tag'

###*
# Clone this tag.
#
# @return {Tag}
# @api private
###

Tag::clone = ->
  err = new Error('tag.clone is deprecated and will be removed in v2.0.0')
  console.warn err.stack
  clone = new Tag(@name, @block.clone())
  clone.line = @line
  clone.attrs = @attrs
  clone.textOnly = @textOnly
  clone

###*
# Check if this tag is an inline tag.
#
# @return {Boolean}
# @api private
###

Tag::isInline = ->
  ~inlineTags.indexOf(@name)

###*
# Check if this tag's contents can be inlined.  Used for pretty printing.
#
# @return {Boolean}
# @api private
###

Tag::canInline = ->
  nodes = @block.nodes
  # Empty tag

  isInline = (node) ->
    # Recurse if the node is a block
    if node.isBlock
      return node.nodes.every(isInline)
    node.isText or node.isInline and node.isInline()

  if !nodes.length
    return true
  # Text-only or inline-only tag
  if 1 == nodes.length
    return isInline(nodes[0])
  # Multi-line inline-only tag
  if @block.nodes.every(isInline)
    i = 1
    len = nodes.length
    while i < len
      if nodes[i - 1].isText and nodes[i].isText
        return false
      ++i
    return true
  # Mixed tag
  false
