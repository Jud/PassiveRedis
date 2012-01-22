inflection   = require './libs/inflection'

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
    Object.defineProperty @, 'prepend',
      value: @constructor.name + ':'
      enumerable: false
      writable: true

    # If __constructed is false, then properties of the passed in
    # `data` variable will be marked as `changed` when assigned
    # to this instance of the object.
    Object.defineProperty @, '__constructed',
      value: if data.id then false else true
      enumerable: false
      writable: true

    # Setup an instance variable that contains available callbacks
    # like beforeUpdate and beforeSave. Use definePeoperty to keep
    # this from being enumerated.
    Object.defineProperty @, 'passive',
      value: 
        beforeUpdate: []
        beforeSave: []
        afterSave: []
      enumerable: false
      writable: true

    # Loop over the schema object in the model class. For now, we
    # are really just looking for key names, which map to redis
    # hash keys, but in the future, there may be types specified
    # in the schema also.
    objProperties = Object.keys @constructor.schema
    objProperties.push 'db'

    objProperties.forEach =>
      name = arguments[0]

      # Because V8 has implimented Object.defineProperty, we can
      # go ahead and set up the peoperties on the schema with getters
      # and setters. This allows us to do nifty things, like have a
      # `changed` object, etc.
      Object.defineProperty @, name,
        # If there is a method called get+Property, then return the
        # value of that function, otherwise, return the value.
        get: =>
          if @['get' + (name.charAt(0).toUpperCase() + name.slice(1))] and !@['___'+name+'Writelock']
            @['___'+name+'Writelock'] = true
            val = @['get' + (name.charAt(0).toUpperCase() + name.slice(1))].call data
            delete @['___'+name+'Writelock']
            return val
          else
            return @['___'+name]

        # If there is a function called set+Property, then pass the set
        # value to this function. Modify the `changed` object to reflect
        # that this property is now dirty.
        set: =>
          if fn = @['set' + (name.charAt(0).toUpperCase() + name.slice(1))]
            if @isConstructed()
              fn.apply @,[arguments[0], (val) =>
                if @[name] isnt val and !(@changed.hasOwnProperty name) then @changed[name] = @[name]
                Object.defineProperty @, '___'+name,
                  value: val
                  enumerable: false
                  writable: true
              ]
            else
              Object.defineProperty @, '___'+name,
                value: arguments[0]
                enumerable: false
                writable: true
          else
            if @isConstructed() and @[name] isnt arguments[0] and !@changed.hasOwnProperty name then @changed[name] = @[name]

            Object.defineProperty @, '___'+name,
              value: arguments[0]
              enumerable: false
              writable: true

        enumerable: true

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
            fn = arguments[arguments.length-1]
            for key, value in arguments when key < arguments.length-1
              args.push i

            @doHasMany.apply @, [name, args, fn]

      # Set up the hasOne relationships. These are called by a method invocation
      # to allow for async operations in the hasOne.
      if rel.hasOne
        Object.keys(rel.hasOne).forEach =>
          name = arguments[0]

          @[name] = (next) =>
            @doHasOneFor name, next

      # hasOne and belongsTo are the same, just different names
      if rel.belongsTo
        Object.keys(rel.belongsTo).forEach =>
          name = arguments[0]

          @[name] = (next) =>
            @doHasOneFor name, next

    # Finally, if we pass an object into the constructor, then, set the data
    # for this model, using the getters and setters we just setup.
    if data
      len = Object.keys(data).length
      keys = Object.keys data
      keys.forEach (key) =>
        @[key] = data[key]
        if !--len
          @__constructed = true
    else
      @__constructed = true

  # Return a boolean if the model has been constructed.
  isConstructed: ->
    !!@__constructed

  getDb: ->
    if !@_db
      @_db = (require 'redis').createClient()

    return @_db

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
          if !@constructor.schema[arguments[0]].required and !@[arguments[0]] and !@constructor.schema[arguments[0]].hasOwnProperty 'default' then info[arguments[0]] = @constructor.schema[arguments[0]].default

        # If we are missing required fields, then return.
        if error then return fn true

        if !err
          # Update the StringId and other pointers
          if @constructor.stringId and (@isChanged @constructor.stringId or force_pointer_update is true) then @updatePointers @constructor.stringId, @changed[@constructor.stringId], @[@constructor.stringId]
          if pointers = @constructor.pointers
            Object.keys(pointers).forEach (key) =>
              if @[key] isnt false
                if (@isChanged @[key]) or (force_pointer_update is true) then @updatePointers key, @changed[key], @[key], !!pointers[key]?.unique

          info.id = @id
          @db.hmset @prepend + @id, info, (err, data) =>
            @db.quit =>
              delete @db
            if !err then fn false, @
        else
          fn true

      if @constructor.actions?.beforeUpdate then @passive.beforeUpdate.push @constructor.actions?.beforeUpdate
      error = false
      if !@passive.beforeUpdate.length
        do_update false
      else
        while @passive.beforeUpdate.length
          closure = @passive.beforeUpdate.pop()
          if !error
            closure.call @, (err) =>
              if !err
                if !@passive.beforeUpdate.length then do_update false
              else
                error = true
                do_update true

    else
      do_save = (err) =>
        # Loop over the schema defined in the model and ONLY push the defined values
        # into the object that will be inserted into the db.
        Object.keys(@constructor.schema).forEach =>
          if @constructor.schema[arguments[0]].required and !@[arguments[0]] then error = true else info[arguments[0]] = @[arguments[0]]
          if !@constructor.schema[arguments[0]].required and !@[arguments[0]] and !@constructor.schema[arguments[0]].hasOwnProperty 'default' then info[arguments[0]] = @constructor.schema[arguments[0]].default

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

              if @constructor.actions?.afterSave then @passive.afterSave.push @constructor.actions?.afterSave
              error = false
              if !@passive.afterSave.length
                @save f, true
              else
                while @passive.afterSave.length
                  closure = @passive.afterSave.pop()
                  if !error
                    closure.call @, =>
                      if !@passive.afterSave.length then @save f, true

            else
              fn true, @
        else
          fn true, @

      if @constructor.actions?.beforeSave then @passive.beforeSave.push @constructor.actions?.beforeSave
      error = false
      if !@passive.beforeSave.length
        do_save false
      else
        while @passive.beforeSave.length
          closure = @passive.beforeSave.pop()
          if !error
            closure.call @, (err) =>
              if !err
                if !@passive.beforeSave.length then do_save false
              else
                error = true
                do_save true

  # Destroy the instance. This method also cleans up any pointer references
  # that may have been accumulated.
  destroy: (next) ->
    if @id
      @updateHasMany 'rem', =>
        @db.del @prepend + @id
        @db.quit =>
          delete @db

        next()
    else
      return next()

  # Update entries that allow us to search for objects by other unique id's,
  # such as the stringId.
  updatePointers: (name, oldVal, newVal, unique=true) ->
    if unique
      @db.del @prepend + name + ':' + oldVal
      @db.set @prepend + name + ':' + newVal, @id
    else
      @db.lrem @prepend + name + ':' + oldVal, 0, @id
      @db.lpush @prepend + name + ':' + newVal, @id

  # If a model has a belongsTo relationship, then we should update the list
  # of hasMany items it is a part of.
  updateHasMany: (type, next) ->
    if len = @constructor.relationships?.belongsTo?.length
      Object.keys(@constructor.relationships.belongsTo).forEach =>
        if foreignId = @[(arguments[0].singularize().toLowerCase())+'Id']
          if type is 'add'
            @db.lpush arguments[0].singularize() + foreignId + ':' + @name, @id, =>
            if !--len
              next()
          else if type is 'rem'
            @db.lrem arguments[0].singularize() + foreignId + ':' + @name, 0, @id, =>
            if !--len
              next()

  # This is used to keep track of the schema values that have been changed
  # after the model was initialized. Either pass in a property string or
  # leave blank to see if the model has changed.
  isChanged: (prop) ->
    if prop
      @changed.hasOwnProperty prop
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
          @db.quit =>
            delete @db

          # Create Callback that is `available` for the factory
          fn = (o) ->
            @['_'+name] = o
            return next false, o

          fn::available = true

          if !err
            @constructor.factory obj, name, fn
    else
      next true

  # Fetch the hasMany relationship specified.
  doHasMany: (type, params, next) ->
    listKey = @prepend + @id + ':' + type
    if next then next::available = true
    @db.smembers listKey, (err, data) =>
      @db.quit =>
        delete @db
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
    fn = if fn and fn::available then fn else ((err, d) => console.log 'found this object, but didn\'t have a callback', type, (if d.id then '#'+d.id else d))

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
      @_findByPointer @stringId, id, db, (err, data) =>
        if !err then return next false, data else return next true

  # Find a model by another unique key, which we will call a pointer to
  # the model's id.
  @_findByPointer: (name, value, db, fn=false) ->
    # If the db parameter is omitted, then the callback function is
    # actually the db variable.
    if Object::toString.call(db) is "[object Function]"
      fn = db
      db = null

    db = if !db then (require 'redis').createClient() else db
    unique = !!@pointers[name]?.unique || name is @stringId

    # Set up the next function to automatically close the db connection
    # when it is invoked.
    next = (e, d) =>
      db.quit()
      if fn then fn e, d

    # This is used to determine if `fn` is defined within its creating closure.
    next::available = !!fn or false

    if unique
      db.get @name + ':' + name + ':' + value, (err, id) =>

        # If there was no error
        if !err
          # If an id exists
          if id
            # Then find by the id!
            @find id, db, next
          else
            # There isn't a pointer defined for this object, so we can't figure
            # out what its id is. So we must return false.
            next false, false
        else
          # An error occurred trying to fetch from the db.
          next true
    else
      # Return all of the items on the list
      db.lrange @name + ':' + name + ':' + value, 0, -1, (err, data) =>
        if !err
          if data
            @find data, db, next
          else
            next false, false
        else
          next true

  # Because of the way PassiveRedis dynamically instantiates models based on
  # the calling class, the model definitions must be defined within the global
  # scope, otherwise dynamic name construction won't work. This method loads
  # the classes into the global scope.
  @loadModels: (models, next) ->
    # If a relative path is passed in
    if models
      Object.keys(models).forEach (name) =>
        if pointers = models[name]?.pointers
          # Setup the pointers to this object that are defined in the model.
          # Secondary indexes might also be a good name.
          Object.keys(pointers).forEach (key) =>
            models[name]['findBy' + (key.charAt(0).toUpperCase() + key.slice(1))] = (value, fn) ->
              @_findByPointer key, value, fn

        global[name] = models[name]

    next()

# Export the module
module.exports = PassiveRedis
