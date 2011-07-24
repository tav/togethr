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
    ###
      => if supports localstorage
        => start listening to local storage changes
      
      // Override `Backbone.sync` to use delegate to the model or collection's
      // *localStorage* property, which should be an instance of `Store`.
      Backbone.sync = function(method, model, options, error) {
        var resp;
        var store = model.localStorage || model.collection.localStorage;
        switch (method) {
          case "read":    resp = model.id ? store.find(model) : store.findAll(); break;
          case "create":  resp = store.create(model);                            break;
          case "update":  resp = store.update(model);                            break;
          case "delete":  resp = store.destroy(model);                           break;
        }
        if (resp) {
          options.success(resp);
        } else {
          options.error("Record not found");
        }
      };
      
    ###
  
  # Sync with localStorage and a server server.
  class ServerBackedLocalCollection extends Backbone.Collection
    ###
      init:
        => if supports localstorage
          => start listening to local storage changes
      
      read:
        => if supports localstorage
          => fetch from local storage
        => fetch from the server
      
      create:
        => store on server
        => if supports localstorage
          => store in local storage
      
      update:
        => store on server
        => if supports localstorage
          => store in local storage
      
      delete:
        => delete on server
        => if supports localstorage
          => store in local storage
      
    ###
    
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
      
    
  
  
  # class LiveCollection extends Backbone.Collection
  
  exports.LocalStore = LocalStore
  exports.LocalModel = LocalModel
  exports.ServerBackedLocalCollection = ServerBackedLocalCollection
  

