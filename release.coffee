'use strict'
fs = require('fs')
pr = require('pull-request')
readdirp = require('lsr').sync
TOKEN = JSON.parse(fs.readFileSync(__dirname + '/.release.json', 'utf8'))
# todo: check that the version is a new un-released version
# todo: check the user has commit access to the github repo
# todo: check the user is an owner in npm
# todo: check History.md has been updated
version = require('./package.json').version
compiledWebsite = require('./docs/stop.js')
compiledWebsite.then(->
  fileUpdates = readdirp(__dirname + '/docs/out').filter((info) ->
    info.isFile()
  ).map((info) ->
    {
      path: info.path.replace(/^\.\//, '')
      content: fs.readFileSync(info.fullPath)
    }
  )
  pr.commit 'jadejs', 'jade', {
    branch: 'gh-pages'
    message: 'Update website for ' + version
    updates: fileUpdates
  }, auth:
    type: 'oauth'
    token: TOKEN
).then(->
  # todo: release the new npm package, set the tag and commit etc.
  return
).done ->
  console.log 'website published'
  return
