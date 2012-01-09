PassiveRedis = require '../'


describe 'Passive Redis ORM', ->
  it 'Should load all models', (done) ->
    PassiveRedis.loadModels (require './models'), ->
      # These two models should be loaded
      (typeof User).should.equal 'function'
      (typeof Cog).should.equal 'function'
      # Make sure everything is sane
      (typeof nonExist).should.equal 'undefined'
      # Boom - First test
      done()
