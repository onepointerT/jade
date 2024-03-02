'use strict'
Node = 
module.exports = ->

###*
# Clone this node (return itself)
#
# @return {Node}
# @api private
###

Node::clone = ->
  err = new Error('node.clone is deprecated and will be removed in v2.0.0')
  console.warn err.stack
  this

Node::type = ''
