'use strict';
var Attrs, Block, Tag, inlineTags;

Attrs = require('./attrs');

Block = require('./block');

inlineTags = require('../inline-tags');


/**
 * Initialize a `Tag` node with the given tag `name` and optional `block`.
 *
 * @param {String} name
 * @param {Block} block
 * @api public
 */

Tag = module.exports = function(name, block) {
  Attrs.call(this);
  this.name = name;
  this.block = block || new Block;
};

Tag.prototype = Object.create(Attrs.prototype);

Tag.prototype.constructor = Tag;

Tag.prototype.type = 'Tag';


/**
 * Clone this tag.
 *
 * @return {Tag}
 * @api private
 */

Tag.prototype.clone = function() {
  var clone, err;
  err = new Error('tag.clone is deprecated and will be removed in v2.0.0');
  console.warn(err.stack);
  clone = new Tag(this.name, this.block.clone());
  clone.line = this.line;
  clone.attrs = this.attrs;
  clone.textOnly = this.textOnly;
  return clone;
};


/**
 * Check if this tag is an inline tag.
 *
 * @return {Boolean}
 * @api private
 */

Tag.prototype.isInline = function() {
  return ~inlineTags.indexOf(this.name);
};


/**
 * Check if this tag's contents can be inlined.  Used for pretty printing.
 *
 * @return {Boolean}
 * @api private
 */

Tag.prototype.canInline = function() {
  var i, isInline, len, nodes;
  nodes = this.block.nodes;
  isInline = function(node) {
    if (node.isBlock) {
      return node.nodes.every(isInline);
    }
    return node.isText || node.isInline && node.isInline();
  };
  if (!nodes.length) {
    return true;
  }
  if (1 === nodes.length) {
    return isInline(nodes[0]);
  }
  if (this.block.nodes.every(isInline)) {
    i = 1;
    len = nodes.length;
    while (i < len) {
      if (nodes[i - 1].isText && nodes[i].isText) {
        return false;
      }
      ++i;
    }
    return true;
  }
  return false;
};
