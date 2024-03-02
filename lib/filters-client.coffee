filter = (name, str, options) ->
  if typeof filter[name] == 'function'
    return filter[name](str, options)
  else
    throw new Error('unknown filter ":' + name + '"')
  return

'use strict'
module.exports = filter
