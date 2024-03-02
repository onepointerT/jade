
/**
 * Filter null `val`s.
 *
 * @param {*} val
 * @return {Boolean}
 * @api private
 */
var jade_encode_char, jade_encode_html_rules, jade_escape, jade_match_html, joinClasses, nulls;

nulls = function(val) {
  return val !== null && val !== '';
};

joinClasses = function(val) {
  return (Array.isArray(val) ? val.map(joinClasses) : val && typeof val === 'object' ? Object.keys(val).filter((function(key) {
    return val[key];
  })) : [val]).filter(nulls).join(' ');
};

jade_encode_char = function(c) {
  return jade_encode_html_rules[c] || c;
};

jade_escape = function(html) {
  var result;
  result = String(html).replace(jade_match_html, jade_encode_char);
  if (result === '' + html) {
    return html;
  } else {
    return result;
  }
};

'use strict';


/**
 * Merge two attribute objects giving precedence
 * to values in object `b`. Classes are special-cased
 * allowing for arrays and merging/joining appropriately
 * resulting in a string.
 *
 * @param {Object} a
 * @param {Object} b
 * @return {Object} a
 * @api private
 */

exports.merge = function(a, b) {
  var ac, attrs, bc, i, key;
  if (arguments.length === 1) {
    attrs = a[0];
    i = 1;
    while (i < a.length) {
      attrs = merge(attrs, a[i]);
      i++;
    }
    return attrs;
  }
  ac = a['class'];
  bc = b['class'];
  if (ac || bc) {
    ac = ac || [];
    bc = bc || [];
    if (!Array.isArray(ac)) {
      ac = [ac];
    }
    if (!Array.isArray(bc)) {
      bc = [bc];
    }
    a['class'] = ac.concat(bc).filter(nulls);
  }
  for (key in b) {
    if (key !== 'class') {
      a[key] = b[key];
    }
  }
  return a;
};


/**
 * join array as classes.
 *
 * @param {*} val
 * @return {String}
 */

exports.joinClasses = joinClasses;


/**
 * Render the given classes.
 *
 * @param {Array} classes
 * @param {Array.<Boolean>} escaped
 * @return {String}
 */

exports.cls = function(classes, escaped) {
  var buf, i, text;
  buf = [];
  i = 0;
  while (i < classes.length) {
    if (escaped && escaped[i]) {
      buf.push(exports.escape(joinClasses([classes[i]])));
    } else {
      buf.push(joinClasses(classes[i]));
    }
    i++;
  }
  text = joinClasses(buf);
  if (text.length) {
    return ' class="' + text + '"';
  } else {
    return '';
  }
};

exports.style = function(val) {
  if (val && typeof val === 'object') {
    return Object.keys(val).map(function(style) {
      return style + ':' + val[style];
    }).join(';');
  } else {
    return val;
  }
};


/**
 * Render the given attribute.
 *
 * @param {String} key
 * @param {String} val
 * @param {Boolean} escaped
 * @param {Boolean} terse
 * @return {String}
 */

exports.attr = function(key, val, escaped, terse) {
  if (key === 'style') {
    val = exports.style(val);
  }
  if ('boolean' === typeof val || null === val) {
    if (val) {
      return ' ' + (terse ? key : key + '="' + key + '"');
    } else {
      return '';
    }
  } else if (0 === key.indexOf('data') && 'string' !== typeof val) {
    if (JSON.stringify(val).indexOf('&') !== -1) {
      console.warn('Since Jade 2.0.0, ampersands (`&`) in data attributes ' + 'will be escaped to `&amp;`');
    }
    if (val && typeof val.toISOString === 'function') {
      console.warn('Jade will eliminate the double quotes around dates in ' + 'ISO form after 2.0.0');
    }
    return ' ' + key + '=\'' + JSON.stringify(val).replace(/'/g, '&apos;') + '\'';
  } else if (escaped) {
    if (val && typeof val.toISOString === 'function') {
      console.warn('Jade will stringify dates in ISO form after 2.0.0');
    }
    return ' ' + key + '="' + exports.escape(val) + '"';
  } else {
    if (val && typeof val.toISOString === 'function') {
      console.warn('Jade will stringify dates in ISO form after 2.0.0');
    }
    return ' ' + key + '="' + val + '"';
  }
};


/**
 * Render the given attributes object.
 *
 * @param {Object} obj
 * @param {Object} escaped
 * @return {String}
 */

exports.attrs = function(obj, terse) {
  var buf, i, key, keys, val;
  buf = [];
  keys = Object.keys(obj);
  if (keys.length) {
    i = 0;
    while (i < keys.length) {
      key = keys[i];
      val = obj[key];
      if ('class' === key) {
        if (val = joinClasses(val)) {
          buf.push(' ' + key + '="' + val + '"');
        }
      } else {
        buf.push(exports.attr(key, val, false, terse));
      }
      ++i;
    }
  }
  return buf.join('');
};


/**
 * Escape the given string of `html`.
 *
 * @param {String} html
 * @return {String}
 * @api private
 */

jade_encode_html_rules = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;'
};

jade_match_html = /[&<>"]/g;

exports.escape = jade_escape;


/**
 * Re-throw the given `err` in context to the
 * the jade in `filename` at the given `lineno`.
 *
 * @param {Error} err
 * @param {String} filename
 * @param {String} lineno
 * @api private
 */

exports.rethrow = function(err, filename, lineno, str) {
  var context;
  var context, end, ex, lines, start;
  if (!(err instanceof Error)) {
    throw err;
  }
  if ((typeof window !== 'undefined' || !filename) && !str) {
    err.message += ' on line ' + lineno;
    throw err;
  }
  try {
    str = str || require('fs').readFileSync(filename, 'utf8');
  } catch (error) {
    ex = error;
    rethrow(err, null, lineno);
  }
  context = 3;
  lines = str.split('\n');
  start = Math.max(lineno - context, 0);
  end = Math.min(lines.length, lineno + context);
  context = lines.slice(start, end).map(function(line, i) {
    var curr;
    curr = i + start + 1;
    return (curr === lineno ? '  > ' : '    ') + curr + '| ' + line;
  }).join('\n');
  err.path = filename;
  err.message = (filename || 'Jade') + ':' + lineno + '\n' + context + '\n\n' + err.message;
  throw err;
};

exports.DebugItem = function(lineno, filename) {
  this.lineno = lineno;
  this.filename = filename;
};
