'use strict';
var Attrs, Mixin;

Attrs = require('./attrs');


/**
 * Initialize a new `Mixin` with `name` and `block`.
 *
 * @param {String} name
 * @param {String} args
 * @param {Block} block
 * @api public
 */

Mixin = module.exports = function(name, args, block, call) {
  Attrs.call(this);
  this.name = name;
  this.args = args;
  this.block = block;
  this.call = call;
};

Mixin.prototype = Object.create(Attrs.prototype);

Mixin.prototype.constructor = Mixin;

Mixin.prototype.type = 'Mixin';
