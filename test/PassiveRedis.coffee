PassiveRedis = require '../'

describe 'Passive Redis ORM', ->
  it 'Should pass a sanity check', ->
    (typeof noVal).should.equal 'undefined'

  it 'Should load all models', (done) ->
    PassiveRedis.loadModels (require './models'), ->
      # These two models should be loaded
      (typeof User).should.equal 'function'
      (typeof Cog).should.equal 'function'

      # Boom - First test
      done()

  it 'Should have hasMany relationships', (done) ->
    user = new User
    (typeof user.cogs).should.equal 'function'
    done()

  it 'Should have hasOne Relationship', (done) ->
    cog = new Cog
    (typeof cog.user).should.equal 'function'
    done()

describe 'User Model', ->
  before (done) ->
    User.db().flushdb done

  testUser = ''
  it 'Should create the User', (done) ->
    User.create {
      email: 'testing@testex.com'
      password: 'newpassword'
    }, (err, user) ->
      testUser = user
      done(err)

  it 'Should be an instance of User', ->
    (testUser instanceof User).should.equal true

  it 'Should have id #1', ->
    testUser.id.should.equal 1

  it 'Should have the correct email address', ->
    testUser.email.should.equal 'testing@testex.com'
