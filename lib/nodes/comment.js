'use strict';
var Comment, Node;

Node = require('./node');


/**
 * Initialize a `Comment` with the given `val`, optionally `buffer`,
 * otherwise the comment may render in the output.
 *
 * @param {String} val
 * @param {Boolean} buffer
 * @api public
 */

Comment = module.exports = function(val, buffer) {
  this.val = val;
  this.buffer = buffer;
};

Comment.prototype = Object.create(Node.prototype);

Comment.prototype.constructor = Comment;

Comment.prototype.type = 'Comment';
