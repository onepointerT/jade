'use strict'
Attrs = require('./attrs')

###*
# Initialize a new `Mixin` with `name` and `block`.
#
# @param {String} name
# @param {String} args
# @param {Block} block
# @api public
###

Mixin = 
module.exports = (name, args, block, call) ->
  Attrs.call this
  @name = name
  @args = args
  @block = block
  @call = call
  return

# Inherit from `Attrs`.
Mixin.prototype = Object.create(Attrs.prototype)
Mixin::constructor = Mixin
Mixin::type = 'Mixin'
