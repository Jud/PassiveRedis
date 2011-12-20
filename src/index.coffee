inflection   = require './libs/inflection'
Promise      = require './libs/Promise'

## isNumber - The missing js is_numeric.
# This is used in our find method to determine if someone is looking
# up by id or by string.
isNumber = (n) ->
  (!isNaN (parseFloat n) and (isFinite n)) || typeof n is 'number'

# The PassiveRedis Class.
class PassiveRedis
  # Because js does not impliment something akin to php's __call
  # magic method, the constructor has to read through the schema
  # of a model and pre-process the getters and setters.
  #
  # The constructor also sets up the methods that would be invoked
  # if you were to call the hasMany or hasOne method names.
  constructor: (data, @db=false, @changed={}) ->
    @prepend = @constructor.name + ':'

    # We try and reuse db objects when possible to avoid creating
    # more connections than necessary to the redis instance.
    if !@db
      @db = (require 'redis').createClient()

    # Loop over the schema object in the model class. For now, we
    # are really just looking for key names, which map to redis
    # hash keys, but in the future, there may be types specified
    # in the schema also.
    Object.keys(@constructor.schema).forEach =>
      name = arguments[0]

      # Because V8 has implimented Object.defineProperty, we can
      # go ahead and set up the peoperties on the schema with getters
      # and setters. This allows us to do nifty things, like have a
      # `changed` object, etc.
      Object.defineProperty @, name, {
        # If there is a method called get+Property, then return the
        # value of that function, otherwise, return the value.
        get: =>
          if @['get' + (name.charAt(0).toUpperCase() + name.slice(1))] then return @['get' + (name.charAt(0).toUpperCase() + name.slice(1))]() else return @['_'+name]

        # If there is a function called set+Property, then pass the set
        # value to this function. Modify the `changed` object to reflect
        # that this property is now dirty.
        set: =>
          if fn = @['set' + (name.charAt(0).toUpperCase() + name.slice(1))]
            fn arguments[0], (val) =>
              if @[name] isnt val and !@changed[name]? then @changed[name] = @[name]
              Object.defineProperty @, '_'+name, {
                value: val
                enumerable: false
                writable: false
              }
          else
            if @[name] isnt arguments[0] and !@changed[name]? then @changed[name] = @[name]

            Object.defineProperty @, '_'+name, {
              value: arguments[0]
              enumerable: false
              writable: false
            }

        enumerable: true
      }

    # Now loop over the fefined relationsips within the model and setup any
    # hasMany and hasOne method calls on object creation.
    if rel = @constructor.relationships
      # Set up the hasMany relationships. These allow for a parameter
      # object to be passed in, which has yet to be implimented. The second
      # parameter is a calback.
      if rel.hasMany
        Object.keys(rel.hasMany).forEach =>
          name = arguments[0]
          @[name] = =>
            args = []
            for i in arguments
              args.push i

            args.unshift name
            @doHasMany.apply @, args

      # Set up the hasOne relationships. These are called by a method invocation
      # to allow for async operations in the hasOne.
      if rel.hasOne
        rel.hasOne.forEach =>
          name = arguments[0]

          @[name] = (params, next) =>
            @doHasOneFor name, next

    # Finally, if we pass an object into the constructor, then, set the data
    # for this model, using the getters and setters we just setup.
    if data
      Object.keys(data).forEach (key) =>
        @[key] = data[key]

  # Save the data in the model. When `force_pointer_update` is set to true,
  # the pointer entry in the db is forced to update, useful when we initially
  # save an item and then need to update the pointer.
  save: (fn, force_pointer_update=false) ->
    info = {}
    error = false

    if @id
      do_update = (err) =>
        # Loop over the schema defined in the model and ONLY push the defined values
        # into the object that will be inserted into the db.
        Object.keys(@constructor.schema).forEach =>
          if @constructor.schema[arguments[0]].required and !@[arguments[0]] then error = true else info[arguments[0]] = @[arguments[0]]

        # If we are missing required fields, then return.
        if error then return fn true

        if !err
          if @constructor.stringId and (@isChanged @[@constructor.stringId] or (force_pointer_update is true and @constructor.stringId)) then @updatePointer @changed[@constructor.stringId], @[@constructor.stringId]
          info.id = @id
          @db.hmset @prepend + @id, info, (err, data) =>
            if !err then fn false, @
        else
          fn true

      if @constructor.actions?.beforeUpdate then @constructor.actions.beforeUpdate.call @, (err) -> do_update err else do_update false
    else
      do_save = (err) =>
        # Loop over the schema defined in the model and ONLY push the defined values
        # into the object that will be inserted into the db.
        Object.keys(@constructor.schema).forEach =>
          if @constructor.schema[arguments[0]].required and !@[arguments[0]] then error = true else info[arguments[0]] = @[arguments[0]]

        # If we are missing required fields, then return.
        if error then return fn true

        if !err
          @db.incr @prepend + '__incr', (err, data) =>
            if !err
              @id = data
              f = (err, data) =>
                @updateHasMany()

                if fn
                  fn err, data
                else
                  console.log 'No callback, here\'s the data', err, data

              @save f, true
            else
              fn true, @
        else
          fn true, @

      if @constructor.actions?.beforeSave then @constructor.actions.beforeSave.call @, (err) -> do_save err else do_save false

  # Destroy the instance. This method also cleans up any pointer references
  # that may have been accumulated.
  destroy: (fn) ->
    if @id
      if @constructor.relationships and @constructor.relationships.belongsTo
        Object.keys(@constructor.relationships.belongsTo).forEach =>
          if foreignId = @[(arguments[0].singularize().toLowerCase())+'Id']
            @db.srem arguments[0].singularize() + foreignId + ':' + @name, @id

      @db.del @prepend + @id
      fn()

    else
      return fn()

  # Update entries that allow us to search for objects by other unique id's,
  # such as the stringId.
  updatePointer: (oldVal, newVal) ->
    @db.del @prepend + oldVal
    @db.set @prepend + newVal, @id

  # If a model has a belongsTo relationship, then we should update the list
  # of hasMany items it is a part of.
  updateHasMany: (type, next) ->
    if @constructor.relationships and @constructor.relationships.belongsTo
      len = @constructor.relationships.belongsTo.length
      Object.keys(@constructor.relationships.belongsTo).forEach =>
        if foreignId = @[(arguments[0].singularize().toLowerCase())+'Id']
          if type is 'add'
            @db.sadd arguments[0].singularize() + foreignId + ':' + @name, @id, =>
            if !--len
              next
          else
            @db.srem arguments[0].singularize() + foreignId + ':' + @name, @id, =>
            if !--len
              next

  # This is used to keep track of the schema values that have been changed
  # after the model was initialized. Either pass in a property string or
  # leave blank to see if the model has changed.
  isChanged: (prop) ->
    if prop
      !!@changed[prop]?
    else
      !!Object.keys(@changed).length

  # Check to see if a model has a hasOne relationship of `type`.
  hasOne: (type) ->
    return (@[type+'Id'] and @[type+'Id'] isnt false)

  # Fetch the relationship specified by the hasOne schema.
  doHasOneFor: (name, next) ->
    if @[name+'Id']
      if @['_'+name]
        return next false, @['_'+name]
      else
        key = name.charAt(0).toUpperCase() + name.slice(1) + ':' + @[name+'Id']
        @db.hgetall key, (err, obj) =>
          if !err
            @constructor.factory obj, name, (o) =>
              @['_'+name] = o
              return next false, o
    else
      next true

  # Fetch the hasMany relationship specified.
  doHasMany: (type, params, next) ->
    listKey = @prepend + @id + ':' + type
    @db.smembers listKey, (err, data) =>
      if !err then @constructor.factory data, type, next else next true

  # Instantiate a new instance of the object and save.
  @create: (data, fn) ->
    return (new @ data).save fn

  # The factory method instantiates models with data that has been fetched
  # from the datastore. In general, we try and return what we were given.
  # If we get an array, then we return an empty array in error cases, and
  # booleans for single item cases.
  @factory: (obj, type, fn) ->
    # If we dont' have a callback, then assign one, more of a dev thing
    fn = if fn::available then fn else ((err, d) => console.log 'found this object, but didn\'t have a callback', type, (if d.id then '#'+d.id else d))

    # if we get an empty array, return an empty array
    if obj instanceof Array and !obj.length then return fn false, []

    # if we get a null or false value, return null or false
    if !obj then return fn false, obj

    # Init the results array
    results = []
    if obj instanceof Array
      obj.forEach (o) =>
        results.push new @ o

      fn false, results
    else
      fn false, new @ obj

  # The find function allow us to find a model by numeric id (default) or
  # stringId if the passed in argument is a string and the specified model
  # has a listed stringId in the schema.
  @find: (id, db, fn=false) ->
    # If the db parameter is omitted, then the callback function is
    # actually the db variable.
    if Object::toString.call(db) is "[object Function]"
      fn = db
      db = null

    # If a db instance wasn't passed in, we need to create one.
    if !db
      db   = (require 'redis').createClient()

    # Here, we modify the callback to close the db connection when it is
    # invoked to keep from opening up extra connections to the redis db.
    next = (e, d) =>
      db.quit()
      if !!fn then fn e, d

    # This is used to let the factory know if we actually have a callback
    # or if it should just print a debug message
    next::available = !!fn or false

    # If we have an array, then loop through, taking advantage of the redis
    # client's built in pipelining.
    if id instanceof Array
      results = []
      len = id.length
      id.forEach (k) =>
        @find k, db, (err, obj) =>
          if obj
            results.push obj
          if !--len then @factory results, @name, next

    # If the passed in argument is a number, then find by the numeric id.
    else if isNumber id
      # find by numeric key
      db.hgetall @name + ':' + id, (err, obj) =>
        if !err
          if Object.keys(obj).length
            @factory obj, @name, next
          else
            @factory false, @name, next
        else next true

    # If all else fails, find by the stringId.
    else
      @findByStringId id, db, (err, data) =>
        if !err then return next false, data else return next true

  # Find objects by their stringId
  @findByStringId: (id, db, fn) ->
    db = if !db then (require 'redis').createClient() else db

    # Set up the next function to automatically close the db connection
    # when it is invoked.
    next = (e, d) =>
      db.quit()
      if fn then fn e, d

    # This is used to determine if `fn` is defined within its creating closure.
    next::available = !!fn or false

    # find by string key, maybe we should try to
    if @string_id and str_id = @string_id
      db.get @name + ':' + str_id + ':' + id, (err, id) ->
        # If there was no error
        if !err
          # If an id exists
          if id
            # Then find by the id!
            @find id, db, (err, obj) ->
              if !err then @factory obj, @name, next
          else
            # There isn't a pointer defined for this object, so we can't figure
            # out what its id is. So we must return false.
            next false, false
        else
          # An error occurred trying to fetch from the db.
          next true
    else
      # This model doesn't define a stringId, so this can't exist.
      next false, false

  # Because of the way PassiveRedis dynamically instantiates models based on
  # the calling class, the model definitions must be defined within the global
  # scope, otherwise dynamic name construction won't work. This method loads
  # the classes into the global scope.
  @loadModels: (path, next) ->
    # If a relative path is passed in
    if (path.split '../').length > 1 then path = (((__dirname.split '/').slice 0, -1).join '/') + '/' + path.split('./')[1]
    if (path.split './').length > 1 then path = __dirname + '/' + path.split('./')[1]

    fs = require 'fs'

    # Iterate over the directory that we have specified
    fs.readdir path, (err, files) ->
      models = []
      files.forEach (file) ->
        name = file.split('.')[0].charAt(0).toUpperCase() + file.split('.')[0].slice(1)
        models.push require path+ '/' +name

      models.forEach (model) ->
        global[Object.keys(model)[0]] = model[Object.keys(model)[0]]

      next()

# Export the module
exports.PassiveRedis = PassiveRedis
