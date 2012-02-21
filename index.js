var PassiveRedis, inflection, isNumber, __db;

inflection = require('./libs/inflection');

__db = (require('redis')).createClient();

isNumber = function(n) {
  return (!isNaN((parseFloat(n)) && (isFinite(n)))) || typeof n === 'number';
};

PassiveRedis = (function() {

  function PassiveRedis(data, db, changed) {
    var keys, len, objProperties, rel,
      _this = this;
    this.db = db != null ? db : false;
    this.changed = changed != null ? changed : {};
    Object.defineProperty(this, 'prepend', {
      value: this.constructor.name + ':',
      enumerable: false,
      writable: true
    });
    Object.defineProperty(this, '__constructed', {
      value: data.id ? false : true,
      enumerable: false,
      writable: true
    });
    Object.defineProperty(this, 'events', {
      value: {
        beforeUpdate: [],
        beforeSave: [],
        afterSave: []
      },
      enumerable: false,
      writable: true
    });
    objProperties = Object.keys(this.constructor.schema);
    objProperties.push('db');
    objProperties.forEach(function() {
      var name;
      name = arguments[0];
      return Object.defineProperty(_this, name, {
        get: function() {
          if (_this['get' + (name.charAt(0).toUpperCase() + name.slice(1))]) {
            return _this['get' + (name.charAt(0).toUpperCase() + name.slice(1))](_this['___' + name]);
          } else {
            return _this['___' + name];
          }
        },
        set: function() {
          var fn;
          if (fn = _this['set' + (name.charAt(0).toUpperCase() + name.slice(1))]) {
            if (_this.isConstructed()) {
              return fn.apply(_this, [
                arguments[0], function(val) {
                  if (_this[name] !== val && !(_this.changed.hasOwnProperty(name))) {
                    _this.changed[name] = _this[name];
                  }
                  return Object.defineProperty(_this, '___' + name, {
                    value: val,
                    enumerable: false,
                    writable: true
                  });
                }
              ]);
            } else {
              return Object.defineProperty(_this, '___' + name, {
                value: arguments[0],
                enumerable: false,
                writable: true
              });
            }
          } else {
            if (_this.isConstructed() && _this[name] !== arguments[0] && !_this.changed.hasOwnProperty(name)) {
              _this.changed[name] = _this[name];
            }
            return Object.defineProperty(_this, '___' + name, {
              value: arguments[0],
              enumerable: false,
              writable: true
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
            var args, fn, key, value, _len;
            args = [];
            fn = arguments[arguments.length - 1];
            for (value = 0, _len = arguments.length; value < _len; value++) {
              key = arguments[value];
              if (key < arguments.length - 1) args.push(i);
            }
            return _this.doHasMany.apply(_this, [name, args, fn]);
          };
        });
      }
      if (rel.hasOne) {
        Object.keys(rel.hasOne).forEach(function() {
          var name;
          name = arguments[0];
          return _this[name] = function(next) {
            return _this.doHasOneFor(name, next);
          };
        });
      }
      if (rel.belongsTo) {
        Object.keys(rel.belongsTo).forEach(function() {
          var name;
          name = arguments[0];
          return _this[name] = function(next) {
            return _this.doHasOneFor(name, next);
          };
        });
      }
    }
    if (data) {
      len = Object.keys(data).length;
      keys = Object.keys(data);
      keys.forEach(function(key) {
        _this[key] = data[key];
        if (!--len) return _this.__constructed = true;
      });
    } else {
      this.__constructed = true;
    }
  }

  PassiveRedis.prototype.isConstructed = function() {
    return !!this.__constructed;
  };

  PassiveRedis.prototype.getDb = function() {
    return __db;
  };

  PassiveRedis.prototype.save = function(fn, force_pointer_update) {
    var closure, do_save, do_update, error, info, _ref, _ref2, _ref3, _ref4, _results, _results2,
      _this = this;
    if (force_pointer_update == null) force_pointer_update = false;
    info = {};
    error = false;
    if (this.id) {
      do_update = function(err) {
        var pointers;
        Object.keys(_this.constructor.schema).forEach(function() {
          if (_this.constructor.schema[arguments[0]].required && !_this[arguments[0]]) {
            error = true;
          } else {
            info[arguments[0]] = _this[arguments[0]];
          }
          if (!_this.constructor.schema[arguments[0]].required && !_this[arguments[0]] && !_this.constructor.schema[arguments[0]].hasOwnProperty('default')) {
            return info[arguments[0]] = _this.constructor.schema[arguments[0]]["default"];
          }
        });
        if (error) return fn(true);
        if (!err) {
          if (_this.constructor.stringId && (_this.isChanged(_this.constructor.stringId || force_pointer_update === true))) {
            _this.updatePointers(_this.constructor.stringId, _this.changed[_this.constructor.stringId], _this[_this.constructor.stringId]);
          }
          if (pointers = _this.constructor.pointers) {
            Object.keys(pointers).forEach(function(key) {
              var _ref;
              if (_this[key] !== false) {
                if ((_this.isChanged(_this[key])) || (force_pointer_update === true)) {
                  return _this.updatePointers(key, _this.changed[key], _this[key], !!((_ref = pointers[key]) != null ? _ref.unique : void 0));
                }
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
        this.events.beforeUpdate.push((_ref2 = this.constructor.actions) != null ? _ref2.beforeUpdate : void 0);
      }
      error = false;
      if (!this.events.beforeUpdate.length) {
        return do_update(false);
      } else {
        _results = [];
        while (this.events.beforeUpdate.length) {
          closure = this.events.beforeUpdate.pop();
          if (!error) {
            _results.push(closure.call(this, function(err) {
              if (!err) {
                if (!_this.events.beforeUpdate.length) return do_update(false);
              } else {
                error = true;
                return do_update(true);
              }
            }));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      }
    } else {
      do_save = function(err) {
        Object.keys(_this.constructor.schema).forEach(function() {
          if (_this.constructor.schema[arguments[0]].required && !_this[arguments[0]]) {
            error = true;
          } else {
            info[arguments[0]] = _this[arguments[0]];
          }
          if (!_this.constructor.schema[arguments[0]].required && !_this[arguments[0]] && !_this.constructor.schema[arguments[0]].hasOwnProperty('default')) {
            return info[arguments[0]] = _this.constructor.schema[arguments[0]]["default"];
          }
        });
        if (error) return fn(true);
        if (!err) {
          return _this.db.incr(_this.prepend + '__incr', function(err, data) {
            var f, _ref3, _ref4, _results2;
            if (!err) {
              _this.id = data;
              f = function(err, data) {
                _this.updateHasMany('add');
                if (fn) {
                  return fn(err, data);
                } else {
                  return console.log('No callback, here\'s the data', err, data);
                }
              };
              if ((_ref3 = _this.constructor.actions) != null ? _ref3.afterSave : void 0) {
                _this.events.afterSave.push((_ref4 = _this.constructor.actions) != null ? _ref4.afterSave : void 0);
              }
              error = false;
              if (!_this.events.afterSave.length) {
                return _this.save(f, true);
              } else {
                _results2 = [];
                while (_this.events.afterSave.length) {
                  closure = _this.events.afterSave.pop();
                  if (!error) {
                    _results2.push(closure.call(_this, function() {
                      if (!_this.events.afterSave.length) {
                        return _this.save(f, true);
                      }
                    }));
                  } else {
                    _results2.push(void 0);
                  }
                }
                return _results2;
              }
            } else {
              return fn(true, _this);
            }
          });
        } else {
          return fn(true, _this);
        }
      };
      if ((_ref3 = this.constructor.actions) != null ? _ref3.beforeSave : void 0) {
        this.events.beforeSave.push((_ref4 = this.constructor.actions) != null ? _ref4.beforeSave : void 0);
      }
      error = false;
      if (!this.events.beforeSave.length) {
        return do_save(false);
      } else {
        _results2 = [];
        while (this.events.beforeSave.length) {
          closure = this.events.beforeSave.pop();
          if (!error) {
            _results2.push(closure.call(this, function(err) {
              if (!err) {
                if (!_this.events.beforeSave.length) return do_save(false);
              } else {
                error = true;
                return do_save(true);
              }
            }));
          } else {
            _results2.push(void 0);
          }
        }
        return _results2;
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
    if (unique) {
      this.db.del(this.prepend + name + ':' + oldVal);
      return this.db.set(this.prepend + name + ':' + newVal, this.id);
    } else {
      this.db.lrem(this.prepend + name + ':' + oldVal, 0, this.id);
      return this.db.lpush(this.prepend + name + ':' + newVal, this.id);
    }
  };

  PassiveRedis.prototype.updateHasMany = function(type, next) {
    var belongsTo, len, _ref, _ref2,
      _this = this;
    if (((_ref = this.constructor.relationships) != null ? _ref.belongsTo : void 0) && typeof ((_ref2 = this.constructor.relationships) != null ? _ref2.belongsTo : void 0) === 'object') {
      belongsTo = this.constructor.relationships.belongsTo;
      len = Object.keys(belongsTo).length;
      next = next || function() {};
      return Object.keys(belongsTo).forEach(function() {
        var classType, foreignId, listKey;
        classType = (arguments[0].singularize()).toLowerCase();
        foreignId = _this[classType + 'Id'];
        listKey = classType + ':' + foreignId + ':' + _this.constructor.name.pluralize().toLowerCase();
        if (foreignId) {
          if (type === 'add') {
            return _this.db.sadd(listKey, _this.id, function() {
              if (!--len) return next();
            });
          } else if (type === 'rem') {
            return _this.db.srem(listKey, 0, _this.id, function() {
              if (!--len) return next();
            });
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
          var fn;
          fn = function(o) {
            this['_' + name] = o;
            return next(false, o);
          };
          fn.prototype.available = true;
          if (!err) return _this.constructor.factory(obj, name, fn);
        });
      }
    } else {
      return next(true);
    }
  };

  PassiveRedis.prototype.doHasMany = function(type, params, next) {
    var listKey,
      _this = this;
    listKey = this.prepend.toLowerCase() + this.id + ':' + type.toLowerCase();
    if (next) next.prototype.available = true;
    return this.db.smembers(listKey, function(err, data) {
      type = type.singularize().charAt(0).toUpperCase() + type.singularize().slice(1);
      if (!err) {
        return global[type].find(data, next);
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
    fn = fn && fn.prototype.available ? fn : (function(err, d) {
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
    if (!db) db = this.db();
    next = function(e, d) {
      if (!!fn) return fn(e, d);
    };
    next.prototype.available = !!fn || false;
    if (id instanceof Array) {
      results = [];
      len = id.length;
      return id.forEach(function(k) {
        return _this.find(k, db, function(err, obj) {
          if (obj && !err) results.push(obj);
          if (!--len) return next(false, results);
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
      return this._findByPointer(this.stringId, id, db, function(err, data) {
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
    db = !db ? this.db() : db;
    unique = !!((_ref = this.pointers[name]) != null ? _ref.unique : void 0) || name === this.stringId;
    next = function(e, d) {
      if (fn) return fn(e, d);
    };
    next.prototype.available = !!fn || false;
    if (unique) {
      return db.get(this.name + ':' + name + ':' + value, function(err, id) {
        if (!err) {
          if (id) {
            return _this.find(id, db, next);
          } else {
            return next(false, false);
          }
        } else {
          return next(true);
        }
      });
    } else {
      return db.lrange(this.name + ':' + name + ':' + value, 0, -1, function(err, data) {
        if (!err) {
          if (data) {
            return _this.find(data, db, next);
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

  PassiveRedis.db = function() {
    return __db;
  };

  return PassiveRedis;

})();

module.exports = PassiveRedis;
