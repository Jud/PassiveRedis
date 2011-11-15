inflection   = require './libs/inflection'
Promise      = require './libs/Promise'

isNumber = (n) ->
  (!isNaN parseFloat n && isFinite n) || typeof n is 'number'

class PassiveRedis
  constructor: (data, @db=false, @changed={}) ->
    @prepend = @constructor.name + ':'

    if !@db
      @db = (require 'redis').createClient()

    Object.keys(@constructor.schema).forEach =>
      name = arguments[0]

      # These are soooo nifty
      Object.defineProperty @, name, {
        get: =>
          if @['get' + (name.charAt(0).toUpperCase() + name.slice(1))]
            return @['get' + (name.charAt(0).toUpperCase() + name.slice(1))]()
          else
            @['_'+name]
        set: =>
          if fn = @['set' + (name.charAt(0).toUpperCase() + name.slice(1))]
            fn arguments[0], (val) =>
              if @[name] isnt val and typeof @changed[name] is 'undefined'
                @changed[name] = @[name]
              Object.defineProperty @, '_'+name, {
                value: val
                enumerable: false
                writable: false
              }
          else
            val = arguments[0]
            if @[name] isnt arguments[0] and typeof @changed[name] is 'undefined'
              @changed[name] = @[name]

            Object.defineProperty @, '_'+name, {
              value: val
              enumerable: false
              writable: false
            }

        enumerable: true
      }

    if rel = @constructor.relationships
      if rel.hasMany
        node_proxy = require 'node-proxy'
        Object.keys(rel.hasMany).forEach =>
          name = arguments[0]

          fp = node_proxy.createFunction {}, =>
            args = []
            for i in arguments
              args.push i

            args.unshift name
            @doHasMany.apply @, args

          @[name] = fp

      if rel.hasOne
        rel.hasOne.forEach =>
          ev = new EventEmitter()
          name = arguments[0]

          @__defineGetter__ name, =>
            @doHasOneFor name, ev

          return ev

    if data
      Object.keys(data).forEach (key) =>
        @[key] = data[key]

  save: (fn, force_pointer_update=false) ->
    # Save the schema values to an object
    info = {}
    Object.keys(@schema).forEach =>
      info[arguments[0]] = @[arguments[0]]

    if @id
      if @string_id and (@isChanged @[@string_id] or force_pointer_update is true)
        @updatePointer @changed[@string_id], @[@string_id]

      info.id = @id
      @db.hmset @prepend + @id, info, (err, data) =>
        if !err
          fn.call false, @
    else
      @db.incr @prepend + '__incr', (err, data) =>
        if !err
          @id = data
          f = (err, data) =>
            if @relationships and @relationships.belongsTo
              Object.keys(@relationships.belongsTo).forEach =>
                if foreignId = @[(arguments[0].singularize().toLowerCase())+'Id']
                  @db.sadd arguments[0].singularize() + foreignId + ':' + @name, @id

            if fn
              fn err, data
            else
              console.log 'No callback, here\'s the data', err, data

          @save f, true
        else
          fn.call true, @

  destroy: (fn) ->
    if @id
      if @relationships and @relationships.belongsTo
        Object.keys(@relationships.belongsTo).forEach =>
          if foreignId = @[(arguments[0].singularize().toLowerCase())+'Id']
            @db.srem arguments[0].singularize() + foreignId + ':' + @name, @id

      @db.del @prepend + @id
      fn.call false

    else
      return fn.call false

  updatePointer: (oldVal, newVal) ->
    @db.del @prepend + oldVal
    @db.set @prepend + newVal, @id

  isChanged: (prop) ->
    if prop
      typeof @changed[prop] isnt 'undefined'
    else
      !!Object.keys(@changed).length

  hasOne: (type) ->
    if @[type+'Id'] and @[type+'Id'] isnt false
      true
    else
      false

  doHasOneFor: (name, ev) ->
    p = new Promise()
    if @[name+'Id']
      if @['_'+name]
        p.value = @['_'+name]
        p.finished = true
        return p
      else
        key = name.charAt(0).toUpperCase() + name.slice(1) + ':' + @[name+'Id']
        @db.hgetall key, (err, obj) =>
          @constructor.factory obj, name, (o) =>
            @['_'+name] = o
            p.finish o
      return p
    else
      false

  doHasMany: (type, params, next) ->
    listKey = @prepend + @id + ':' + type
    @db.smembers listKey, (err, data) =>
      if !err then @constructor.factory data, type, next else next true

  @factory: (obj, type, fn) ->
    console.log 'factory', obj, type, fn
    # If we dont' have a callback, then assign one
    fn = if fn::available then fn else ((err, d) => console.log 'found this object, but didn\'t have a callback', type, (if d.id then '#'+d.id else d))

    # if we get an empty array, return an empty array
    if obj instanceof Array and !obj.length then return fn false, []

    # if we get a null or false value, return null or false
    if !obj then return fn false, obj

    results = []
    if obj instanceof Array
      obj.forEach (o) =>
        results.push new global[type] o

      fn false, results
    else
      fn false, new global[type] obj

  @find: (id, f) ->
    db = (require 'redis').createClient()
    fn = (e, d) =>
      db.quit()
      f e, d
    fn::available = if f then true else false

    if id instanceof Array
      results = []
      len = id.length
      id.forEach (k) =>
        doIdLookup = (id) =>
          if id
            db.hgetall @name + ':' + k, (err, obj) =>
              if !err and obj
                if Object.keys(obj).length then results.push obj

              if !--len
                @factory results, @name, fn
          else
            if !--len
              @factory results, @name, fn

        if isNumber k
          doIdLookup k
        else
          @findByStringId id, (err, data) =>
            if !err
              doIdLookup data

    else if isNumber id
      # find by numeric key
      db.hgetall @name + ':' + id, (err, obj) =>
        if !err
          @factory obj, @name, fn
        else
          fn true
    else
      @findByStringId id, (err, data) =>
        if !err
          @factory data, @name, fn
        else
          fn true

  @findByStringId: (id, f) ->
    db = (require 'redis').createClient()
    fn = (e, d) =>
      db.quit()
      f e, d
    fn::available = if f then true else false

    try
      # find by string key
      if @string_id and str_id = @string_id
        db.get @name + ':' + str_id + ':' + id, (err, id) ->
          if !err
            if id
              db.hgetall @name + ':' + id, (err, obj) ->
                if !err
                  if obj
                    fn false, obj
                  else
                    fn false, false
                else
                  fn true
            else
              fn false, false
          else
            fn true
      else
        fn false, []
    catch e
      console.log 'Had a problem loading', @name
      fn true

  @loadModels: (path, next) ->
    # If a relative path is passed in
    if (path.split './').length > 1
      newPath = __dirname.split('/')
      newPath.splice(-2,2)
      path = newPath.join('/') + '/' + (path.split('./')[1])

    fs = require 'fs'
    fs.readdir path, (err, files) =>
      models = []
      files.forEach (file) ->
        name = file.split('.')[0]
        models.push require path+ '/' +name

      models.forEach (model) =>
        global[Object.keys(model)[0]] = model[Object.keys(model)[0]]

      next()

exports.PassiveRedis = PassiveRedis
