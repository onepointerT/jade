'use strict';
var Attrs, Node;

Node = require('./node');


/**
 * Initialize a `Attrs` node.
 *
 * @api public
 */

Attrs = module.exports = function() {
  this.attributeNames = [];
  this.attrs = [];
  this.attributeBlocks = [];
};

Attrs.prototype = Object.create(Node.prototype);

Attrs.prototype.constructor = Attrs;

Attrs.prototype.type = 'Attrs';


/**
 * Set attribute `name` to `val`, keep in mind these become
 * part of a raw js object literal, so to quote a value you must
 * '"quote me"', otherwise or example 'user.name' is literal JavaScript.
 *
 * @param {String} name
 * @param {String} val
 * @param {Boolean} escaped
 * @return {Tag} for chaining
 * @api public
 */

Attrs.prototype.setAttribute = function(name, val, escaped) {
  if (name !== 'class' && this.attributeNames.indexOf(name) !== -1) {
    throw new Error('Duplicate attribute "' + name + '" is not allowed.');
  }
  this.attributeNames.push(name);
  this.attrs.push({
    name: name,
    val: val,
    escaped: escaped
  });
  return this;
};


/**
 * Remove attribute `name` when present.
 *
 * @param {String} name
 * @api public
 */

Attrs.prototype.removeAttribute = function(name) {
  var err, i, len;
  err = new Error('attrs.removeAttribute is deprecated and will be removed in v2.0.0');
  console.warn(err.stack);
  i = 0;
  len = this.attrs.length;
  while (i < len) {
    if (this.attrs[i] && this.attrs[i].name === name) {
      delete this.attrs[i];
    }
    ++i;
  }
};


/**
 * Get attribute value by `name`.
 *
 * @param {String} name
 * @return {String}
 * @api public
 */

Attrs.prototype.getAttribute = function(name) {
  var err, i, len;
  err = new Error('attrs.getAttribute is deprecated and will be removed in v2.0.0');
  console.warn(err.stack);
  i = 0;
  len = this.attrs.length;
  while (i < len) {
    if (this.attrs[i] && this.attrs[i].name === name) {
      return this.attrs[i].val;
    }
    ++i;
  }
};

Attrs.prototype.addAttributes = function(src) {
  this.attributeBlocks.push(src);
};
