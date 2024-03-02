'use strict'
Node = require('./node')

###*
# Initialize a `Text` node with optional `line`.
#
# @param {String} line
# @api public
###

Text = 
module.exports = (line) ->
  @val = line
  return

# Inherit from `Node`.
Text.prototype = Object.create(Node.prototype)
Text::constructor = Text
Text::type = 'Text'

###*
# Flag as text.
###

Text::isText = true
