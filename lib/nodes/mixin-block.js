'use strict';
var MixinBlock, Node;

Node = require('./node');


/**
 * Initialize a new `Block` with an optional `node`.
 *
 * @param {Node} node
 * @api public
 */

MixinBlock = module.exports = function() {};

MixinBlock.prototype = Object.create(Node.prototype);

MixinBlock.prototype.constructor = MixinBlock;

MixinBlock.prototype.type = 'MixinBlock';
