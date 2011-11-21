(function() {
  var PassiveRedis, Promise, inflection, isNumber;

  inflection = require('./libs/inflection');

  Promise = require('./libs/Promise');

  isNumber = function(n) {
    return (!isNaN((parseFloat(n)) && (isFinite(n)))) || typeof n === 'number';
  };

  PassiveRedis = (function() {

    function PassiveRedis(data, db, changed) {
      var rel;
      var _this = this;
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
            var fn, val;
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
              val = arguments[0];
              if (_this[name] !== arguments[0] && !(_this.changed[name] != null)) {
                _this.changed[name] = _this[name];
              }
              return Object.defineProperty(_this, '_' + name, {
                value: val,
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
              return _this.doHasOneFor(name, params, next);
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

    PassiveRedis.prototype.create = function(data, fn) {
      var obj;
      obj = new this(data, this.db);
      return obj.save(fn);
    };

    PassiveRedis.prototype.save = function(fn, force_pointer_update) {
      var info;
      var _this = this;
      if (force_pointer_update == null) force_pointer_update = false;
      info = {};
      Object.keys(this.schema).forEach(function() {
        return info[arguments[0]] = _this[arguments[0]];
      });
      if (this.id) {
        if (this.string_id && (this.isChanged(this[this.string_id] || force_pointer_update === true))) {
          this.updatePointer(this.changed[this.string_id], this[this.string_id]);
        }
        info.id = this.id;
        return this.db.hmset(this.prepend + this.id, info, function(err, data) {
          if (!err) return fn.call(false, _this);
        });
      } else {
        return this.db.incr(this.prepend + '__incr', function(err, data) {
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
            return fn.call(true, _this);
          }
        });
      }
    };

    PassiveRedis.prototype.destroy = function(fn) {
      var _this = this;
      if (this.id) {
        if (this.relationships && this.relationships.belongsTo) {
          Object.keys(this.relationships.belongsTo).forEach(function() {
            var foreignId;
            if (foreignId = _this[(arguments[0].singularize().toLowerCase()) + 'Id']) {
              return _this.db.srem(arguments[0].singularize() + foreignId + ':' + _this.name, _this.id);
            }
          });
        }
        this.db.del(this.prepend + this.id);
        return fn();
      } else {
        return fn();
      }
    };

    PassiveRedis.prototype.updatePointer = function(oldVal, newVal) {
      this.db.del(this.prepend + oldVal);
      return this.db.set(this.prepend + newVal, this.id);
    };

    PassiveRedis.prototype.updateHasMany = function(type, next) {
      var len;
      var _this = this;
      if (this.relationships && this.relationships.belongsTo) {
        len = this.relationships.belongsTo.length;
        return Object.keys(this.relationships.belongsTo).forEach(function() {
          var foreignId;
          if (foreignId = _this[(arguments[0].singularize().toLowerCase()) + 'Id']) {
            if (type === 'add') {
              _this.db.sadd(arguments[0].singularize() + foreignId + ':' + _this.name, _this.id, function() {});
              if (!--len) return next;
            } else {
              _this.db.srem(arguments[0].singularize() + foreignId + ':' + _this.name, _this.id, function() {});
              if (!--len) return next;
            }
          }
        });
      }
    };

    PassiveRedis.prototype.isChanged = function(prop) {
      if (prop) {
        return !!(this.changed[prop] != null);
      } else {
        return !!Object.keys(this.changed).length;
      }
    };

    PassiveRedis.prototype.hasOne = function(type) {
      if (this[type + 'Id'] && this[type + 'Id'] !== false) {
        return true;
      } else {
        return false;
      }
    };

    PassiveRedis.prototype.doHasOneFor = function(name, ev) {
      var key, p;
      var _this = this;
      p = new Promise();
      if (this[name + 'Id']) {
        if (this['_' + name]) {
          p.value = this['_' + name];
          p.finished = true;
          return p;
        } else {
          key = name.charAt(0).toUpperCase() + name.slice(1) + ':' + this[name + 'Id'];
          this.db.hgetall(key, function(err, obj) {
            return _this.constructor.factory(obj, name, function(o) {
              _this['_' + name] = o;
              return p.finish(o);
            });
          });
        }
        return p;
      } else {
        return false;
      }
    };

    PassiveRedis.prototype.doHasMany = function(type, params, next) {
      var listKey;
      var _this = this;
      listKey = this.prepend + this.id + ':' + type;
      return this.db.smembers(listKey, function(err, data) {
        if (!err) {
          return _this.constructor.factory(data, type, next);
        } else {
          return next(true);
        }
      });
    };

    PassiveRedis.factory = function(obj, type, fn) {
      var results;
      var _this = this;
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
      var len, next, results;
      var _this = this;
      if (fn == null) fn = false;
      if (Object.prototype.toString.call(db) === "[object Function]") {
        fn = db;
        db = null;
      }
      if (!db) db = (require('redis')).createClient();
      next = function(e, d) {
        db.quit();
        return fn(e, d);
      };
      next.prototype.available = fn ? true : false;
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
        return this.findByStringId(id, db, function(err, data) {
          if (!err) {
            return _this.factory(data, _this.name, next);
          } else {
            return next(true);
          }
        });
      }
    };

    PassiveRedis.findByStringId = function(id, db, fn) {
      var next, str_id;
      var _this = this;
      db = !db ? (require('redis')).createClient() : db;
      next = function(e, d) {
        db.quit();
        return fn(e, d);
      };
      next.prototype.available = fn ? true : false;
      if (this.string_id && (str_id = this.string_id)) {
        return db.get(this.name + ':' + str_id + ':' + id, function(err, id) {
          if (!err) {
            if (id) {
              return db.hgetall(this.name + ':' + id, function(err, obj) {
                if (!err) {
                  if (obj) {
                    return next(false, obj);
                  } else {
                    return next(false, []);
                  }
                } else {
                  return next(true);
                }
              });
            } else {
              return next(false, []);
            }
          } else {
            return next(true);
          }
        });
      } else {
        return next(false, []);
      }
    };

    PassiveRedis.loadModels = function(path, next) {
      var fs, newPath;
      if ((path.split('./')).length > 1) {
        newPath = __dirname.split('/');
        newPath.splice(-2, 2);
        path = newPath.join('/') + '/' + (path.split('./')[1]);
      }
      fs = require('fs');
      return fs.readdir(path, function(err, files) {
        var models;
        models = [];
        files.forEach(function(file) {
          var name;
          name = file.split('.')[0];
          return models.push(require(path + '/' + name));
        });
        models.forEach(function(model) {
          return global[Object.keys(model)[0]] = model[Object.keys(model)[0]];
        });
        return next();
      });
    };

    return PassiveRedis;

  })();

  exports.PassiveRedis = PassiveRedis;

}).call(this);
