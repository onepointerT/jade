'use strict';
var Filter, Node;

Node = require('./node');


/**
 * Initialize a `Filter` node with the given
 * filter `name` and `block`.
 *
 * @param {String} name
 * @param {Block|Node} block
 * @api public
 */

Filter = module.exports = function(name, block, attrs) {
  this.name = name;
  this.block = block;
  this.attrs = attrs;
};

Filter.prototype = Object.create(Node.prototype);

Filter.prototype.constructor = Filter;

Filter.prototype.type = 'Filter';
