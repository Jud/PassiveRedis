var PassiveRedis, inflection, isNumber;

inflection = require('./libs/inflection');

isNumber = function(n) {
  return (!isNaN((parseFloat(n)) && (isFinite(n)))) || typeof n === 'number';
};

PassiveRedis = (function() {

  function PassiveRedis(data, db, changed) {
    var rel,
      _this = this;
    this.db = db != null ? db : false;
    this.changed = changed != null ? changed : {};
    this.prepend = this.constructor.name + ':';
    if (!this.db) this.db = (require('redis')).createClient();
    Object.keys(this.constructor.schema).forEach(function() {
      var name;
      name = arguments[0];
      return Object.defineProperty(_this, name, {
        get: function() {
          if (_this['get' + (name.charAt(0).toUpperCase() + name.slice(1))]) {
            return _this['get' + (name.charAt(0).toUpperCase() + name.slice(1))]();
          } else {
            return _this['_' + name];
          }
        },
        set: function() {
          var fn;
          if (fn = _this['set' + (name.charAt(0).toUpperCase() + name.slice(1))]) {
            return fn(arguments[0], function(val) {
              if (_this[name] !== val && !(_this.changed[name] != null)) {
                _this.changed[name] = _this[name];
              }
              return Object.defineProperty(_this, '_' + name, {
                value: val,
                enumerable: false,
                writable: false
              });
            });
          } else {
            if (_this[name] !== arguments[0] && !(_this.changed[name] != null)) {
              _this.changed[name] = _this[name];
            }
            return Object.defineProperty(_this, '_' + name, {
              value: arguments[0],
              enumerable: false,
              writable: false
            });
          }
        },
        enumerable: true
      });
    });
    if (rel = this.constructor.relationships) {
      if (rel.hasMany) {
        Object.keys(rel.hasMany).forEach(function() {
          var name;
          name = arguments[0];
          return _this[name] = function() {
            var args, i, _i, _len;
            args = [];
            for (_i = 0, _len = arguments.length; _i < _len; _i++) {
              i = arguments[_i];
              args.push(i);
            }
            args.unshift(name);
            return _this.doHasMany.apply(_this, args);
          };
        });
      }
      if (rel.hasOne) {
        rel.hasOne.forEach(function() {
          var name;
          name = arguments[0];
          return _this[name] = function(params, next) {
            return _this.doHasOneFor(name, next);
          };
        });
      }
    }
    if (data) {
      Object.keys(data).forEach(function(key) {
        return _this[key] = data[key];
      });
    }
  }

  PassiveRedis.prototype.save = function(fn, force_pointer_update) {
    var do_save, do_update, error, info, _ref, _ref2,
      _this = this;
    if (force_pointer_update == null) force_pointer_update = false;
    info = {};
    error = false;
    if (this.id) {
      do_update = function(err) {
        var pointers;
        Object.keys(_this.constructor.schema).forEach(function() {
          if (_this.constructor.schema[arguments[0]].required && !_this[arguments[0]]) {
            return error = true;
          } else {
            return info[arguments[0]] = _this[arguments[0]];
          }
        });
        if (error) return fn(true);
        if (!err) {
          if (_this.constructor.stringId && (_this.isChanged(_this[_this.constructor.stringId] || (force_pointer_update === true && _this.constructor.stringId)))) {
            _this.updatePointer(_this.constructor.stringId, _this.changed[_this.constructor.stringId], _this[_this.constructor.stringId]);
          }
          if (pointers = _this.constructor.pointers) {
            Object.keys(pointers).forEach(function(key) {
              var _ref;
              if (_this.isChanged(_this[field] || (force_pointer_update === true))) {
                return _this.updatePointer(key, _this.changed[field], _this[field], !!((_ref = pointers[key]) != null ? _ref.unique : void 0));
              }
            });
          }
          info.id = _this.id;
          return _this.db.hmset(_this.prepend + _this.id, info, function(err, data) {
            if (!err) return fn(false, _this);
          });
        } else {
          return fn(true);
        }
      };
      if ((_ref = this.constructor.actions) != null ? _ref.beforeUpdate : void 0) {
        return this.constructor.actions.beforeUpdate.call(this, function(err) {
          return do_update(err);
        });
      } else {
        return do_update(false);
      }
    } else {
      do_save = function(err) {
        Object.keys(_this.constructor.schema).forEach(function() {
          if (_this.constructor.schema[arguments[0]].required && !_this[arguments[0]]) {
            return error = true;
          } else {
            return info[arguments[0]] = _this[arguments[0]];
          }
        });
        if (error) return fn(true);
        if (!err) {
          return _this.db.incr(_this.prepend + '__incr', function(err, data) {
            var f;
            if (!err) {
              _this.id = data;
              f = function(err, data) {
                _this.updateHasMany();
                if (fn) {
                  return fn(err, data);
                } else {
                  return console.log('No callback, here\'s the data', err, data);
                }
              };
              return _this.save(f, true);
            } else {
              return fn(true, _this);
            }
          });
        } else {
          return fn(true, _this);
        }
      };
      if ((_ref2 = this.constructor.actions) != null ? _ref2.beforeSave : void 0) {
        return this.constructor.actions.beforeSave.call(this, function(err) {
          return do_save(err);
        });
      } else {
        return do_save(false);
      }
    }
  };

  PassiveRedis.prototype.destroy = function(next) {
    var _this = this;
    if (this.id) {
      return this.updateHasMany('rem', function() {
        _this.db.del(_this.prepend + _this.id);
        return next();
      });
    } else {
      return next();
    }
  };

  PassiveRedis.prototype.updatePointers = function(name, oldVal, newVal, unique) {
    if (unique == null) unique = true;
    if (oldVal !== void 0) {
      if (unique) {
        this.db.del(this.prepend + name + ':' + oldVal);
        return this.db.set(this.prepend + name + ':' + newVal, this.id);
      } else {
        this.db.lrem(this.prepend + name + ':' + oldVal, 0, this.id);
        return this.db.lpush(this.prepend + name + ':' + newVal, this.id);
      }
    }
  };

  PassiveRedis.prototype.updateHasMany = function(type, next) {
    var len, _ref, _ref2,
      _this = this;
    if (len = (_ref = this.constructor.relationships) != null ? (_ref2 = _ref.belongsTo) != null ? _ref2.length : void 0 : void 0) {
      return Object.keys(this.constructor.relationships.belongsTo).forEach(function() {
        var foreignId;
        if (foreignId = _this[(arguments[0].singularize().toLowerCase()) + 'Id']) {
          if (type === 'add') {
            _this.db.lpush(arguments[0].singularize() + foreignId + ':' + _this.name, _this.id, function() {});
            if (!--len) return next();
          } else if (type === 'rem') {
            _this.db.lrem(arguments[0].singularize() + foreignId + ':' + _this.name, 0, _this.id, function() {});
            if (!--len) return next();
          }
        }
      });
    }
  };

  PassiveRedis.prototype.isChanged = function(prop) {
    if (prop) {
      return this.changed.hasOwnProperty(prop);
    } else {
      return !!Object.keys(this.changed).length;
    }
  };

  PassiveRedis.prototype.hasOne = function(type) {
    return this[type + 'Id'] && this[type + 'Id'] !== false;
  };

  PassiveRedis.prototype.doHasOneFor = function(name, next) {
    var key,
      _this = this;
    if (this[name + 'Id']) {
      if (this['_' + name]) {
        return next(false, this['_' + name]);
      } else {
        key = name.charAt(0).toUpperCase() + name.slice(1) + ':' + this[name + 'Id'];
        return this.db.hgetall(key, function(err, obj) {
          if (!err) {
            return _this.constructor.factory(obj, name, function(o) {
              _this['_' + name] = o;
              return next(false, o);
            });
          }
        });
      }
    } else {
      return next(true);
    }
  };

  PassiveRedis.prototype.doHasMany = function(type, params, next) {
    var listKey,
      _this = this;
    listKey = this.prepend + this.id + ':' + type;
    return this.db.smembers(listKey, function(err, data) {
      if (!err) {
        return _this.constructor.factory(data, type, next);
      } else {
        return next(true);
      }
    });
  };

  PassiveRedis.create = function(data, fn) {
    return (new this(data)).save(fn);
  };

  PassiveRedis.factory = function(obj, type, fn) {
    var results,
      _this = this;
    fn = fn.prototype.available ? fn : (function(err, d) {
      return console.log('found this object, but didn\'t have a callback', type, (d.id ? '#' + d.id : d));
    });
    if (obj instanceof Array && !obj.length) return fn(false, []);
    if (!obj) return fn(false, obj);
    results = [];
    if (obj instanceof Array) {
      obj.forEach(function(o) {
        return results.push(new _this(o));
      });
      return fn(false, results);
    } else {
      return fn(false, new this(obj));
    }
  };

  PassiveRedis.find = function(id, db, fn) {
    var len, next, results,
      _this = this;
    if (fn == null) fn = false;
    if (Object.prototype.toString.call(db) === "[object Function]") {
      fn = db;
      db = null;
    }
    if (!db) db = (require('redis')).createClient();
    next = function(e, d) {
      db.quit();
      if (!!fn) return fn(e, d);
    };
    next.prototype.available = !!fn || false;
    if (id instanceof Array) {
      results = [];
      len = id.length;
      return id.forEach(function(k) {
        return _this.find(k, db, function(err, obj) {
          if (obj) results.push(obj);
          if (!--len) return _this.factory(results, _this.name, next);
        });
      });
    } else if (isNumber(id)) {
      return db.hgetall(this.name + ':' + id, function(err, obj) {
        if (!err) {
          if (Object.keys(obj).length) {
            return _this.factory(obj, _this.name, next);
          } else {
            return _this.factory(false, _this.name, next);
          }
        } else {
          return next(true);
        }
      });
    } else {
      return this._findByPointer(this.stringId, true, id, db, function(err, data) {
        if (!err) {
          return next(false, data);
        } else {
          return next(true);
        }
      });
    }
  };

  PassiveRedis._findByPointer = function(name, value, db, fn) {
    var next, unique, _ref,
      _this = this;
    if (fn == null) fn = false;
    if (Object.prototype.toString.call(db) === "[object Function]") {
      fn = db;
      db = null;
    }
    db = !db ? (require('redis')).createClient() : db;
    unique = ((_ref = this.pointers[key]) != null ? _ref.unique : void 0) || false;
    next = function(e, d) {
      db.quit();
      if (fn) return fn(e, d);
    };
    next.prototype.available = !!fn || false;
    if (!unique) {
      return db.get(this.name + ':' + name + ':' + this[name], function(err, id) {
        if (!err) {
          if (id) {
            return _this.find(id, db, function(err, obj) {
              if (!err) return _this.factory(obj, _this.name, next);
            });
          } else {
            return next(false, false);
          }
        } else {
          return next(true);
        }
      });
    } else {
      return db.lrange(this.name + ':' + name + ':' + this[name], 0, -1, function(err, data) {
        if (!err) {
          if (data) {
            return _this.find(data, db, function(err, obj) {
              if (!err) return _this.factory(obj, _this.name, next);
            });
          } else {
            return next(false, false);
          }
        } else {
          return next(true);
        }
      });
    }
  };

  PassiveRedis.loadModels = function(models, next) {
    var _this = this;
    if (models) {
      Object.keys(models).forEach(function(name) {
        var pointers, _ref;
        if (pointers = (_ref = models[name]) != null ? _ref.pointers : void 0) {
          Object.keys(pointers).forEach(function(key) {
            return models[name]['findBy' + (key.charAt(0).toUpperCase() + key.slice(1))] = function(value, fn) {
              return this._findByPointer(key, value, fn);
            };
          });
        }
        return global[name] = models[name];
      });
    }
    return next();
  };

  return PassiveRedis;

})();

module.exports = PassiveRedis;
