'use strict'
Node = require('./node')

###*
# Initialize a `Filter` node with the given
# filter `name` and `block`.
#
# @param {String} name
# @param {Block|Node} block
# @api public
###

Filter = 
module.exports = (name, block, attrs) ->
  @name = name
  @block = block
  @attrs = attrs
  return

# Inherit from `Node`.
Filter.prototype = Object.create(Node.prototype)
Filter::constructor = Filter
Filter::type = 'Filter'
