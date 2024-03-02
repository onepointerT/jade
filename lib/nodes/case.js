'use strict';
var Case, Node, When, exports;

Node = require('./node');


/**
 * Initialize a new `Case` with `expr`.
 *
 * @param {String} expr
 * @api public
 */

Case = exports = module.exports = function(expr, block) {
  this.expr = expr;
  this.block = block;
};

Case.prototype = Object.create(Node.prototype);

Case.prototype.constructor = Case;

Case.prototype.type = 'Case';

When = exports.When = function(expr, block) {
  this.expr = expr;
  this.block = block;
  this.debug = false;
};

When.prototype = Object.create(Node.prototype);

When.prototype.constructor = When;

When.prototype.type = 'When';
