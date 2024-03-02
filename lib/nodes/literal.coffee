'use strict'
Node = require('./node')

###*
# Initialize a `Literal` node with the given `str.
#
# @param {String} str
# @api public
###

Literal = 
module.exports = (str) ->
  @str = str
  return

# Inherit from `Node`.
Literal.prototype = Object.create(Node.prototype)
Literal::constructor = Literal
Literal::type = 'Literal'
