'use strict'
Node = require('./node')

###*
# Initialize a new `Block` with an optional `node`.
#
# @param {Node} node
# @api public
###

Block = 
module.exports = (node) ->
  @nodes = []
  if node
    @push node
  return

# Inherit from `Node`.
Block.prototype = Object.create(Node.prototype)
Block::constructor = Block
Block::type = 'Block'

###*
# Block flag.
###

Block::isBlock = true

###*
# Replace the nodes in `other` with the nodes
# in `this` block.
#
# @param {Block} other
# @api private
###

Block::replace = (other) ->
  err = new Error('block.replace is deprecated and will be removed in v2.0.0')
  console.warn err.stack
  other.nodes = @nodes
  return

###*
# Push the given `node`.
#
# @param {Node} node
# @return {Number}
# @api public
###

Block::push = (node) ->
  @nodes.push node

###*
# Check if this block is empty.
#
# @return {Boolean}
# @api public
###

Block::isEmpty = ->
  0 == @nodes.length

###*
# Unshift the given `node`.
#
# @param {Node} node
# @return {Number}
# @api public
###

Block::unshift = (node) ->
  @nodes.unshift node

###*
# Return the "last" block, or the first `yield` node.
#
# @return {Block}
# @api private
###

Block::includeBlock = ->
  ret = this
  node = undefined
  i = 0
  len = @nodes.length
  while i < len
    node = @nodes[i]
    if node.yield
      return node
    else if node.textOnly
      ++i
      continue
    else if node.includeBlock
      ret = node.includeBlock()
    else if node.block and !node.block.isEmpty()
      ret = node.block.includeBlock()
    if ret.yield
      return ret
    ++i
  ret

###*
# Return a clone of this block.
#
# @return {Block}
# @api private
###

Block::clone = ->
  err = new Error('block.clone is deprecated and will be removed in v2.0.0')
  console.warn err.stack
  clone = new Block
  i = 0
  len = @nodes.length
  while i < len
    clone.push @nodes[i].clone()
    ++i
  clone
