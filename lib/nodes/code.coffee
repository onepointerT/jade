'use strict'
Node = require('./node')

###*
# Initialize a `Code` node with the given code `val`.
# Code may also be optionally buffered and escaped.
#
# @param {String} val
# @param {Boolean} buffer
# @param {Boolean} escape
# @api public
###

Code = 
module.exports = (val, buffer, escape) ->
  @val = val
  @buffer = buffer
  @escape = escape
  if val.match(/^ *else/)
    @debug = false
  return

# Inherit from `Node`.
Code.prototype = Object.create(Node.prototype)
Code::constructor = Code
Code::type = 'Code'
# prevent the minifiers removing this
