var CleanCSS, alternatives, deprecated, filter, getMarkdownImplementation, jstransformer, transformers, uglify, warned;

getMarkdownImplementation = function() {
  var ex, implementations;
  implementations = ['marked', 'supermarked', 'markdown-js', 'markdown'];
  while (implementations.length) {
    try {
      require(implementations[0]);
      return implementations[0];
    } catch (error) {
      ex = error;
      implementations.shift();
    }
  }
  return 'markdown-it';
};

filter = function(name, str, options) {
  var ex, implementation, result, tr;
  if (typeof filter[name] === 'function') {
    return filter[name](str, options);
  } else {
    tr = void 0;
    try {
      tr = jstransformer(require('jstransformer-' + name));
    } catch (error) {
      ex = error;
    }
    if (tr) {
      result = tr.render(str, options, options).body;
      if (options && options.minify) {
        try {
          switch (tr.outputFormat) {
            case 'js':
              result = uglify.minify(result, {
                fromString: true
              }).code;
              break;
            case 'css':
              result = (new CleanCSS).minify(result).styles;
          }
        } catch (error) {
          ex = error;
        }
      }
      return result;
    } else if (transformers[name]) {
      if (!warned[name]) {
        warned[name] = true;
        if (name === 'md' || name === 'markdown') {
          implementation = getMarkdownImplementation();
          console.log('Transformers.' + name + ' is deprecated, you must replace the :' + name + ' jade filter, with :' + implementation + ' and install jstransformer-' + implementation + ' before you update to jade@2.0.0.');
        } else if (alternatives[name]) {
          console.log('Transformers.' + name + ' is deprecated, you must replace the :' + name + ' jade filter, with :' + alternatives[name] + ' and install jstransformer-' + alternatives[name] + ' before you update to jade@2.0.0.');
        } else {
          console.log('Transformers.' + name + ' is deprecated, to continue using the :' + name + ' jade filter after jade@2.0.0, you will need to install jstransformer-' + name.toLowerCase() + '.');
        }
      }
      return transformers[name].renderSync(str, options);
    } else {
      throw new Error('unknown filter ":' + name + '"');
    }
  }
};

'use strict';

transformers = require('transformers');

jstransformer = require('jstransformer');

uglify = require('uglify-js');

CleanCSS = require('clean-css');

warned = {};

alternatives = {
  uglifyJS: 'uglify-js',
  uglify: 'uglify-js',
  uglifyCSS: 'clean-css',
  'uglify-css': 'clean-css',
  uglifyJSON: 'json',
  'uglify-json': 'json',
  live: 'livescript',
  LiveScript: 'livescript',
  ls: 'livescript',
  coffeekup: 'coffeecup',
  styl: 'stylus',
  coffee: 'coffee-script',
  coffeescript: 'coffee-script',
  coffeeScript: 'coffee-script',
  css: 'verbatim',
  js: 'verbatim'
};

deprecated = ['jqtpl', 'jazz'];

module.exports = filter;
