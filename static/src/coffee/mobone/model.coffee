# Base ``Backbone.Model`` and ``Backbone.Collection`` classes.
#
namespace 'mobone.model', (exports) ->
  
  # `LocalStore` provides a CRUD interface to `window.localStorage`.
  class LocalStore
    
    stub: 'mobone:'
    namespace: null
    
    _key: (id) ->
      "#{@namespace}-#{id}"
      
    
    _store: (model) ->
      key = @_key model.id
      item =
        data: model.toJSON()
        __metadata:
          key: key,
          modified: +new Date
      value = JSON.stringify item
      @storage.setItem key, value
      
    
    _save: -> 
      key = @namespace
      item =
        data: @records
        __metadata:
          key: key,
          modified: +new Date
      value = JSON.stringify item
      @storage.setItem key, value
      
    
    
    refresh: ->
      records = []
      if @storage?
        value = @storage.getItem @namespace
        if value?
          data = JSON.parse value
          records = data.data
      @records = records
      
    
    
    create: (model) ->
      if not model.id?
        model.id = model.attributes.id = mobone.math.uuid()
      @_store model
      @records.push "#{model.id}"
      @_save()
      model
      
    
    read: (target) ->
      if target instanceof Backbone.Collection
        @refresh()
        items = []
        for id in @records
          value = @storage.getItem @_key id
          data = JSON.parse value
          items.push data.data
        items
      else
        if target instanceof Backbone.Model
          key = @_key target.id
        else
          key = @_key target
        value = @storage.getItem key
        if value?
          data = JSON.parse value
          data.data
        
      
    
    update: (model) ->
      @_store model
      @records.push "#{model.id}" if not ("#{model.id}" in @records)
      @_save()
      model
      
    
    delete: (model) ->
      key = @_key model.id
      @storage.removeItem key
      @records = _.without @records, "#{model.id}"
      @_save()
      model
      
    
    
    constructor: (namespace, storage) ->
      # setup a (hopefully globably unique) namespace
      namespace = namespace ? @namespace
      throw '`namespace` is required' if not namespace?
      @namespace = "#{@stub}#{namespace}"
      # setup `@storage` and read in the stored `@records`
      @storage = storage ? window.localStorage
      @refresh()
      
    
    
  
  # `LocalModel` is a `Model` that persists its data in a `LocalStore`.
  class LocalModel extends Backbone.Model
    
    storage_name: null
    track_changes: false
    
    # Handle storage events to update if changed and destroy if removed.
    handleStorage: (event) =>
      # The storage `event.key` property is not implemented in most browsers,
      # So we inspect the `__metadata` we saved as a workaround.
      if event.newValue? and event.newValue
        data = JSON.parse event.newValue
        if data.__metadata?
          key = data.__metadata.key
          # If the event happened to this instance.
          if key is @storage._key @id
            # update the model
            @set data.data
          
        
      
    
    # Use `@storage` to read and store data.
    sync: (method, target, options) ->
      return options.error "No `localStorage`." if not @storage.storage?
      resp = @storage[method] target
      if resp then options.success resp else options.error "Record not found."
      
    
    # Setup `@storage` and, if required, start listening to changes.
    initialize: (attrs, opts) ->
      opts ?= {}
      storage_name = if opts.storage_name? then opts.storage_name else @storage_name
      throw '`storage_name` is required' if not storage_name?
      @storage = new LocalStore storage_name
      track_changes = if opts.track_changes? then opts.track_changes else @track_changes
      $(window).bind 'storage', @handleStorage if track_changes
      
    
    
  
  # `LocalCollection` is a `Collection` that persists its data in a `LocalStore`.
  class LocalCollection extends Backbone.Collection
  
    storage_name: null
    track_changes: false
    
    # Handle storage events to add new records and remove deleted ones.
    handleStorage: (event) => 
      # The storage `event.key` property is not implemented in most browsers,
      # So we inspect the `__metadata` we saved as a workaround.
      if event.newValue? and event.newValue
        data = JSON.parse event.newValue
        if data.__metadata?
          key = data.__metadata.key
          # If the event happened to this collection.
          if key is @storage.namespace
            existing_records = @storage.records
            @storage.refresh()
            new_records = @storage.records
            # add new records
            for item in new_records
              if not (item in existing_records)
                @sync 'read', item, success: (resp) => @add resp
            # remove deleted records
            for item in existing_records
              if not (item in new_records)
                @remove @get item 
      
    
    # Use `@storage` to fetch records.
    sync: (method, target, options) ->
      return options.error "No `localStorage`." if not @storage.storage?
      resp = @storage[method] target
      if resp then options.success resp else options.error "Records not found."
      
    
    # Setup `@storage` and, if required, start listening to changes.
    initialize: (attrs, opts) ->
      opts ?= {}
      storage_name = if opts.storage_name? then opts.storage_name else @storage_name
      throw '`storage_name` is required' if not storage_name?
      @storage = new LocalStore storage_name
      track_changes = if opts.track_changes? then opts.track_changes else @track_changes
      $(window).bind 'storage', @handleStorage if track_changes
      
    
    
  
  
  # `ServerBackedLocalModel` is a `Model` that persists its data on the server
  # *and* caches it in a `LocalStore`.
  class ServerBackedLocalModel extends LocalModel
    
    # Delegates sync to `Backbone.sync` and updates `@storage` on success.
    sync: (method, target, options) ->
      storage = @storage
      success = options.success
      options.success = (resp) ->
        storage[method] target if method isnt 'read' and storage.storage?
        success resp
      Backbone.sync.call this, method, this, options
      
    
  
  
  # `ServerBackedLocalCollection` is a `Collection` that reads and writes to
  # localStorage and a server.
  class ServerBackedLocalCollection extends LocalCollection
    
    # Override `Backbone.Collection._add` to update a model if it exists already
    # rather than throwing an error.
    _add: (model, options) =>
      options ?= {}
      model = @_prepareModel model, options
      return false if not model
      existing = @getByCid(model) or @get(model)
      if existing
        existing.set model.toJSON()
        model = existing
      @_byId[model.id] = model
      @_byCid[model.cid] = model
      if options.at?
        index = then options.at
      else
        if @comparator
          index = @sortedIndex model, @comparator
        else
          index = @length
      @models.splice index, 0, model
      model.bind 'all', @_onModelEvent
      @length++;
      model.trigger 'add', model, @, options if not (options.silent or existing)
      model
      
    
    
    # If method is `read`, looks in `@storage` first and then reads from server,
    # updating existing records when the server results come back.
    # Otherwise delegates sync to `Backbone.sync` and updates `@storage` on success.
    sync: (method, target, options) ->
      
      storage = @storage
      success = options.success
      
      # We always want to add on fetch.
      options.add = true
      
      if method is 'read'
        # Read syncronously from local storage.
        resp = @storage[method] target if @storage.storage?
        # Populate the collection.
        @add @parse resp if resp?
      else
        # Update `@storage` when the server results come back.
        options.success = (resp) ->
          storage[method] target if storage.storage?
          success resp
        
      # Fetch results from the server using `Backbone.sync`.
      Backbone.sync.call this, method, this, options
      
    
    
  
  # `RecentInstanceCache` listens to `model:added` events and adds models that
  # are instances of @model.  Maintains Sorts by the used flag and
  # follows a least recently used algorithm to limit the size of the cache.
  class RecentInstanceCache extends Backbone.Collection
    
    # You must provide a specific model class.
    model: null
    
    # How many instances to keep in the cache?
    limit: 350
    
    # Update the `model`'s `__used` attribute to be a timestamp of now.
    _update_used: (model) ->
      attrs = 
        __used: +new Date
      opts = 
        silent: true
      model.set attrs, opts
      
    
    
    # Override `get` to update `__used`.
    get: ->
      model = super
      if model?
        @_update_used model
      model
      
    
    # Override `_add` to update `__used`.
    _add: ->
      model = super
      if model?
        @_update_used model
      model
      
    
    
    # Override `add` to remove the least recently used models when the `@limit`
    # of the number of models the cache can contain is reached.
    add: ->
      super
      if @length > @limit
        @sort()
        to_remove = []
        for i in [@limit..@length-1]
          to_remove.push @at i
        @remove to_remove
      
    
    
    # Keep the collection sorted by when `__used`.
    comparator: (model) ->
      0 - model.get '__used'
      
    
    
    # Add model instances that match the type of @model and are not already in
    # the collection.
    handleAdded: (event, model) => 
      @add model if model instanceof @model and not @get model
      
    
    
    # Start handling `model:added` events.
    initialize: -> 
      $(document).bind 'model:added', @handleAdded
      throw "You must provide @model." if not @model?
      
    
    
  
  # class LiveCollection extends Backbone.Collection
  
  exports.LocalStore = LocalStore
  exports.LocalModel = LocalModel
  exports.LocalCollection = LocalCollection
  exports.ServerBackedLocalModel = ServerBackedLocalModel
  exports.ServerBackedLocalCollection = ServerBackedLocalCollection
  exports.RecentInstanceCache = RecentInstanceCache
  

