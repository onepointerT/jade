'use strict'
Node = require('./node')

###*
# Initialize an `Each` node, representing iteration
#
# @param {String} obj
# @param {String} val
# @param {String} key
# @param {Block} block
# @api public
###

Each = 
module.exports = (obj, val, key, block) ->
  @obj = obj
  @val = val
  @key = key
  @block = block
  return

# Inherit from `Node`.
Each.prototype = Object.create(Node.prototype)
Each::constructor = Each
Each::type = 'Each'
