PassiveRedis = require '../../'

class User extends PassiveRedis
  @stringId: 'email'

  @pointers:
    key:
      unique: true

  @schema:
    email:
      required: true
    password:
      required: true
    key:
      required: true
    secret:
      required: true

  @relationships:
    hasMany:
      cogs: {}

  @actions:
    beforeUpdate: (next)->
      if @isChanged 'password'
        crypto    = require 'crypto'
        @password = crypto.createHash('md5').update('testing').digest("hex")

      else
        next false

    beforeSave: (next) ->
      # Now generate an API key and secret for this user
      crypto = require 'crypto'

      # Assign the key and secret
      @key = crypto.createHash('md5').update('Unique').digest("hex")
      @secret = crypto.createHash('md5').update('Not Really').digest("hex")

      next false

exports.User = User
