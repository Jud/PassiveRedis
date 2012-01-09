var Cog, PassiveRedis,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

PassiveRedis = require('../../');

Cog = (function(_super) {

  __extends(Cog, _super);

  function Cog() {
    Cog.__super__.constructor.apply(this, arguments);
  }

  Cog.schema = {
    userId: {
      required: true
    },
    message: {
      required: true
    }
  };

  Cog.relationships = {
    belongsTo: {
      user: {}
    }
  };

  return Cog;

})(PassiveRedis);

exports.Cog = Cog;
