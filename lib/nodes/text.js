'use strict';
var Node, Text;

Node = require('./node');


/**
 * Initialize a `Text` node with optional `line`.
 *
 * @param {String} line
 * @api public
 */

Text = module.exports = function(line) {
  this.val = line;
};

Text.prototype = Object.create(Node.prototype);

Text.prototype.constructor = Text;

Text.prototype.type = 'Text';


/**
 * Flag as text.
 */

Text.prototype.isText = true;
