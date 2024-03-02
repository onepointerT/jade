getMarkdownImplementation = ->
  implementations = [
    'marked'
    'supermarked'
    'markdown-js'
    'markdown'
  ]
  while implementations.length
    try
      require implementations[0]
      return implementations[0]
    catch ex
      implementations.shift()
  'markdown-it'

filter = (name, str, options) ->
  if typeof filter[name] == 'function'
    return filter[name](str, options)
  else
    tr = undefined
    try
      tr = jstransformer(require('jstransformer-' + name))
    catch ex
    if tr
      # TODO: we may want to add a way for people to separately specify "locals"
      result = tr.render(str, options, options).body
      if options and options.minify
        try
          switch tr.outputFormat
            when 'js'
              result = uglify.minify(result, fromString: true).code
            when 'css'
              result = (new CleanCSS).minify(result).styles
        catch ex
          # better to fail to minify than output nothing
      return result
    else if transformers[name]
      if !warned[name]
        warned[name] = true
        if name == 'md' or name == 'markdown'
          implementation = getMarkdownImplementation()
          console.log 'Transformers.' + name + ' is deprecated, you must replace the :' + name + ' jade filter, with :' + implementation + ' and install jstransformer-' + implementation + ' before you update to jade@2.0.0.'
        else if alternatives[name]
          console.log 'Transformers.' + name + ' is deprecated, you must replace the :' + name + ' jade filter, with :' + alternatives[name] + ' and install jstransformer-' + alternatives[name] + ' before you update to jade@2.0.0.'
        else
          console.log 'Transformers.' + name + ' is deprecated, to continue using the :' + name + ' jade filter after jade@2.0.0, you will need to install jstransformer-' + name.toLowerCase() + '.'
      return transformers[name].renderSync(str, options)
    else
      throw new Error('unknown filter ":' + name + '"')
  return

'use strict'
transformers = require('transformers')
jstransformer = require('jstransformer')
uglify = require('uglify-js')
CleanCSS = require('clean-css')
warned = {}
alternatives = 
  uglifyJS: 'uglify-js'
  uglify: 'uglify-js'
  uglifyCSS: 'clean-css'
  'uglify-css': 'clean-css'
  uglifyJSON: 'json'
  'uglify-json': 'json'
  live: 'livescript'
  LiveScript: 'livescript'
  ls: 'livescript'
  coffeekup: 'coffeecup'
  styl: 'stylus'
  coffee: 'coffee-script'
  coffeescript: 'coffee-script'
  coffeeScript: 'coffee-script'
  css: 'verbatim'
  js: 'verbatim'
deprecated = [
  'jqtpl'
  'jazz'
]
module.exports = filter
