'use strict';
var BlockComment, Node;

Node = require('./node');


/**
 * Initialize a `BlockComment` with the given `block`.
 *
 * @param {String} val
 * @param {Block} block
 * @param {Boolean} buffer
 * @api public
 */

BlockComment = module.exports = function(val, block, buffer) {
  this.block = block;
  this.val = val;
  this.buffer = buffer;
};

BlockComment.prototype = Object.create(Node.prototype);

BlockComment.prototype.constructor = BlockComment;

BlockComment.prototype.type = 'BlockComment';
