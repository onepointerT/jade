'use strict'
Node = require('./node')

###*
# Initialize a `BlockComment` with the given `block`.
#
# @param {String} val
# @param {Block} block
# @param {Boolean} buffer
# @api public
###

BlockComment = 
module.exports = (val, block, buffer) ->
  @block = block
  @val = val
  @buffer = buffer
  return

# Inherit from `Node`.
BlockComment.prototype = Object.create(Node.prototype)
BlockComment::constructor = BlockComment
BlockComment::type = 'BlockComment'
