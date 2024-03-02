'use strict';
var Code, Node;

Node = require('./node');


/**
 * Initialize a `Code` node with the given code `val`.
 * Code may also be optionally buffered and escaped.
 *
 * @param {String} val
 * @param {Boolean} buffer
 * @param {Boolean} escape
 * @api public
 */

Code = module.exports = function(val, buffer, escape) {
  this.val = val;
  this.buffer = buffer;
  this.escape = escape;
  if (val.match(/^ *else/)) {
    this.debug = false;
  }
};

Code.prototype = Object.create(Node.prototype);

Code.prototype.constructor = Code;

Code.prototype.type = 'Code';
