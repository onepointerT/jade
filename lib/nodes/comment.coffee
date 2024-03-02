'use strict'
Node = require('./node')

###*
# Initialize a `Comment` with the given `val`, optionally `buffer`,
# otherwise the comment may render in the output.
#
# @param {String} val
# @param {Boolean} buffer
# @api public
###

Comment = 
module.exports = (val, buffer) ->
  @val = val
  @buffer = buffer
  return

# Inherit from `Node`.
Comment.prototype = Object.create(Node.prototype)
Comment::constructor = Comment
Comment::type = 'Comment'
