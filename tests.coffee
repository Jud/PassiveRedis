vows = require 'vows'
PassiveRedis = (require './index').PassiveRedis

suite = vows.describe 'Testing ORM functions'

suite.addBatch
  'Texting creation of client':
    topic: new(PassiveRedis)
    'Should connect to db': (topic) ->
      assert.ok topic.db
