'use strict'
Node = require('./node')

###*
# Initialize a new `Case` with `expr`.
#
# @param {String} expr
# @api public
###

Case = exports =
module.exports = (expr, block) ->
  @expr = expr
  @block = block
  return

# Inherit from `Node`.
Case.prototype = Object.create(Node.prototype)
Case::constructor = Case
Case::type = 'Case'
When = 
exports.When = (expr, block) ->
  @expr = expr
  @block = block
  @debug = false
  return

# Inherit from `Node`.
When.prototype = Object.create(Node.prototype)
When::constructor = When
When::type = 'When'
