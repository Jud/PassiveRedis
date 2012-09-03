PassiveRedis = require '../'

# Load the models
Models = require './models'
User = Models.User
Cog  = Models.Cog

# Setup used variables
testUser = testCog = foundUser = foundCogs = null

describe 'Passive Redis ORM', ->
  it 'Should pass a sanity check', ->
    (typeof noVal).should.equal 'undefined'

  it 'Should load all models', (done) ->
    PassiveRedis.loadModels Models, ->
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

describe 'User Model Tests', ->
  before (d) ->
    User.db().flushdb d

  it 'Should create the User', (done) ->
    opts =
      email: 'testing@testex.com'
      password: 'newpassword'

    User.create opts, (err, user) ->
      testUser = user
      done err, user

  it 'Should be an instance of User', ->
    (testUser instanceof User).should.equal true

  it 'Should have id #1', ->
    testUser.id.should.equal 1

  it 'Should have the correct email address', ->
    testUser.email.should.equal 'testing@testex.com'

describe 'Cog Model Tests', ->
  it 'Should create a new Cog', (done) ->
    opts =
      userId: testUser.id
      message: 'I am a COG'

    Cog.create opts, (err, cog) ->
      testCog = cog
      done err

  it 'Should find the user of the Cog', (done) ->
    testCog.user (err, u) ->
      foundUser = u
      done null

  it 'Should have the correct id', (done) ->
    foundUser.id.should.equal testUser.id
    done()

  it 'Should have the same email', (done) ->
    foundUser.email.should.equal testUser.email
    done()

describe 'User hasMany Tests', ->
  it 'Should have one Cog', (done) ->
    foundUser.cogs (err, cogs) ->
      foundCogs = cogs
      cogs.length.should.equal 1
      done()

  it 'Should have the same message', (done) ->
    foundCogs[0].message.should.equal 'I am a COG'
    done()

  it 'Should return the correct user (basically a sanity check)', (done) ->
    foundCogs[0].user (err, user) ->
      user.id.should.equal foundUser.id
      done()

describe 'User getter tests', ->
  it 'Should have a name', ->
    foundUser.name.should.equal 'undefinedheyoo'

  it 'Should allow a name to be set', (done) ->
    foundUser.name = 'Judson'
    foundUser.save done

  it 'Should use the getter correctly', (done) ->
    User.find foundUser.id, (err, user) ->
      if !err
        user.name.should.equal 'Judsonheyoo'
        done()

describe 'Create another Cog', ->
  it 'Should create a cog', (done) ->
    opts =
      userId: testUser.id
      message: 'I am COG #2'

    Cog.create opts, (err, cog) ->
      testCog = cog
      done err

  it 'Should reflect that in the user HasMany', (done) ->
    testUser.cogs (err, cogs) ->
      cogs.length.should.equal 2
      done()

describe 'Cog deletion', ->
  it 'Should successfully delete the cog', (done) ->
    testUser.cogs (err, cogs) ->
      cogs.pop().destroy (err, h) ->
        done()

  it 'Should have the correct cogs count', (done) ->
    testUser.cogs (err, cogs) ->
      cogs.length.should.equal 1
      done()

describe 'User deletion', ->
  it 'Should delete the User', (done) ->
    testUser.destroy ->
      done()

  it 'Should delete the cogs', (done) ->
    testUser.cogs (err, cogs) ->
      cogs.length.should.equal 0
      done()

  it 'Should clean up the pointer keys', (done) ->
    User.db().keys '*', (err, keys) ->
      keys.length.should.equal 2
      done()

describe 'User creation should have the correct id', ->
  it 'Should create a new user', (done) ->
    opts =
      email: 'testing@testex.com'
      password: 'newpassword'

    User.create opts, (err, user) ->
      if !err
        testUser = user
        done err, user

  it 'Should have id #2', ->
    testUser.id.should.equal 2

  it 'Should delete this user', (done) ->
    testUser.destroy ->
      done()

describe 'Finished!', ->
  it 'Should flush the db', (done) ->
    User.db().flushdb
    done()
