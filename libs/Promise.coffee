EventEmitter = require('events').EventEmitter
scope = @

class Promise
  constructor: (@finished=false, @fns=[]) ->

  finish: (value) ->
    @finished = true
    @fns.forEach ->
      arguments[0](value)

  with: (fn) ->
    if @finished is true
      fn @value
    else
      @fns.push fn

exports.Promise = Promise
