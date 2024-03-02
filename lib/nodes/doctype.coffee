'use strict'
Node = require('./node')

###*
# Initialize a `Doctype` with the given `val`. 
#
# @param {String} val
# @api public
###

Doctype = 
module.exports = (val) ->
  @val = val
  return

# Inherit from `Node`.
Doctype.prototype = Object.create(Node.prototype)
Doctype::constructor = Doctype
Doctype::type = 'Doctype'
