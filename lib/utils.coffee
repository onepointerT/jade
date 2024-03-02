'use strict'

###*
# Merge `b` into `a`.
#
# @param {Object} a
# @param {Object} b
# @return {Object}
# @api public
###

exports.merge = (a, b) ->
  for key of b
    a[key] = b[key]
  a

exports.stringify = (str) ->
  JSON.stringify(str).replace(/\u2028/g, '\\u2028').replace /\u2029/g, '\\u2029'

exports.walkAST = (ast, before, after) ->
  before and before(ast)
  switch ast.type
    when 'Block'
      ast.nodes.forEach (node) ->
        walkAST node, before, after
        return
    when 'Case', 'Each', 'Mixin', 'Tag', 'When', 'Code'
      ast.block and walkAST(ast.block, before, after)
    when 'Attrs', 'BlockComment', 'Comment', 'Doctype', 'Filter', 'Literal', 'MixinBlock', 'Text'
    else
      throw new Error('Unexpected node type ' + ast.type)
      break
  after and after(ast)
  return
