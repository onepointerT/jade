'use strict';
var Each, Node;

Node = require('./node');


/**
 * Initialize an `Each` node, representing iteration
 *
 * @param {String} obj
 * @param {String} val
 * @param {String} key
 * @param {Block} block
 * @api public
 */

Each = module.exports = function(obj, val, key, block) {
  this.obj = obj;
  this.val = val;
  this.key = key;
  this.block = block;
};

Each.prototype = Object.create(Node.prototype);

Each.prototype.constructor = Each;

Each.prototype.type = 'Each';
