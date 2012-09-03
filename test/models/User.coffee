PassiveRedis = require '../../'

class User extends PassiveRedis
  @stringId: 'email'

  @pointers:
    key:
      unique: true
    name:
      unique: false

  @schema:
    email:
      required: true
    name:
      required: false
    password:
      required: true
    key:
      required: true
    secret:
      required: true

  @relationships:
    hasMany:
      cogs: {}


  getName: (curvalue) ->
    curvalue+'heyoo'

  @actions:
    beforeUpdate: (next)->
      if @isChanged 'password'
        crypto    = require 'crypto'
        @password = crypto.createHash('md5').update(@password).digest("hex")

      next false

    beforeSave: (next) ->
      # Now generate an API key and secret for this user
      crypto = require 'crypto'

      # Assign the key and secret
      @key = crypto.createHash('md5').update('Unique').digest("hex")
      @secret = crypto.createHash('md5').update('Not Really').digest("hex")

      next false

exports.User = User
