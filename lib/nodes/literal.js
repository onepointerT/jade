'use strict';
var Literal, Node;

Node = require('./node');


/**
 * Initialize a `Literal` node with the given `str.
 *
 * @param {String} str
 * @api public
 */

Literal = module.exports = function(str) {
  this.str = str;
};

Literal.prototype = Object.create(Node.prototype);

Literal.prototype.constructor = Literal;

Literal.prototype.type = 'Literal';
