'use strict'
Node = require('./node')

###*
# Initialize a new `Block` with an optional `node`.
#
# @param {Node} node
# @api public
###

MixinBlock = 
module.exports = ->

# Inherit from `Node`.
MixinBlock.prototype = Object.create(Node.prototype)
MixinBlock::constructor = MixinBlock
MixinBlock::type = 'MixinBlock'
