var PassiveRedis, User,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

PassiveRedis = require('../../');

User = (function(_super) {

  __extends(User, _super);

  function User() {
    User.__super__.constructor.apply(this, arguments);
  }

  User.stringId = 'email';

  User.pointers = {
    key: {
      unique: true
    }
  };

  User.schema = {
    email: {
      required: true
    },
    password: {
      required: true
    },
    key: {
      required: true
    },
    secret: {
      required: true
    }
  };

  User.relationships = {
    hasMany: {
      cogs: {}
    }
  };

  User.actions = {
    beforeUpdate: function(next) {
      var crypto;
      if (this.isChanged('password')) {
        crypto = require('crypto');
        return this.password = crypto.createHash('md5').update('testing').digest("hex");
      } else {
        return next(false);
      }
    },
    beforeSave: function(next) {
      var crypto;
      crypto = require('crypto');
      this.key = crypto.createHash('md5').update('Unique').digest("hex");
      this.secret = crypto.createHash('md5').update('Not Really').digest("hex");
      return next(false);
    }
  };

  return User;

})(PassiveRedis);

exports.User = User;
