PassiveRedis = require '../../'

class Cog extends PassiveRedis

  @schema:
    userId:
      required: true
    message:
      required: true

  @relationships:
    belongsTo:
      user: {}

exports.Cog = Cog
