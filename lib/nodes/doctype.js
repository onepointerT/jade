'use strict';
var Doctype, Node;

Node = require('./node');


/**
 * Initialize a `Doctype` with the given `val`. 
 *
 * @param {String} val
 * @api public
 */

Doctype = module.exports = function(val) {
  this.val = val;
};

Doctype.prototype = Object.create(Node.prototype);

Doctype.prototype.constructor = Doctype;

Doctype.prototype.type = 'Doctype';
