'use strict';
var Block, Node;

Node = require('./node');


/**
 * Initialize a new `Block` with an optional `node`.
 *
 * @param {Node} node
 * @api public
 */

Block = module.exports = function(node) {
  this.nodes = [];
  if (node) {
    this.push(node);
  }
};

Block.prototype = Object.create(Node.prototype);

Block.prototype.constructor = Block;

Block.prototype.type = 'Block';


/**
 * Block flag.
 */

Block.prototype.isBlock = true;


/**
 * Replace the nodes in `other` with the nodes
 * in `this` block.
 *
 * @param {Block} other
 * @api private
 */

Block.prototype.replace = function(other) {
  var err;
  err = new Error('block.replace is deprecated and will be removed in v2.0.0');
  console.warn(err.stack);
  other.nodes = this.nodes;
};


/**
 * Push the given `node`.
 *
 * @param {Node} node
 * @return {Number}
 * @api public
 */

Block.prototype.push = function(node) {
  return this.nodes.push(node);
};


/**
 * Check if this block is empty.
 *
 * @return {Boolean}
 * @api public
 */

Block.prototype.isEmpty = function() {
  return 0 === this.nodes.length;
};


/**
 * Unshift the given `node`.
 *
 * @param {Node} node
 * @return {Number}
 * @api public
 */

Block.prototype.unshift = function(node) {
  return this.nodes.unshift(node);
};


/**
 * Return the "last" block, or the first `yield` node.
 *
 * @return {Block}
 * @api private
 */

Block.prototype.includeBlock = function() {
  var i, len, node, ret;
  ret = this;
  node = void 0;
  i = 0;
  len = this.nodes.length;
  while (i < len) {
    node = this.nodes[i];
    if (node["yield"]) {
      return node;
    } else if (node.textOnly) {
      ++i;
      continue;
    } else if (node.includeBlock) {
      ret = node.includeBlock();
    } else if (node.block && !node.block.isEmpty()) {
      ret = node.block.includeBlock();
    }
    if (ret["yield"]) {
      return ret;
    }
    ++i;
  }
  return ret;
};


/**
 * Return a clone of this block.
 *
 * @return {Block}
 * @api private
 */

Block.prototype.clone = function() {
  var clone, err, i, len;
  err = new Error('block.clone is deprecated and will be removed in v2.0.0');
  console.warn(err.stack);
  clone = new Block;
  i = 0;
  len = this.nodes.length;
  while (i < len) {
    clone.push(this.nodes[i].clone());
    ++i;
  }
  return clone;
};
