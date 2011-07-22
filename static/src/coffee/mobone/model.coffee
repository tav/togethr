# Base ``Backbone.Model`` and ``Backbone.Collection`` classes.
#
namespace 'mobone.model', (exports) ->
  
  # `LocalStore` provides a CRUD interface to `window.localStorage`.
  #
  class LocalStore
    
    _store: (model) ->
      key = "#{@namespace}-#{model.id}"
      value = JSON.stringify model
      @storage.setItem key, value
      
    
    _save: -> 
      key = @namespace
      value = @records.join ','
      @storage.setItem key, value
      
    
    
    create: (model) ->
      if not model.id?
        model.id = model.attributes.id = mobone.math.uuid()
      @_store model
      @records.push "#{model.id}"
      @_save()
      model
      
    
    read: (model) ->
      if model?
        key = "#{@namespace}-#{model.id}"
        value = @storage.getItem key
        JSON.parse value if value?
      else
        JSON.parse [@storage.getItem "#{@namespace}-#{id}" for id in @records]
      
    
    update: (model) ->
      @_store model
      @records.push "#{model.id}" if not "#{model.id}" in @records
      @_save()
      model
      
    
    delete: (model) ->
      key = "#{@namespace}-#{model.id}"
      @storage.removeItem key
      @records = _.without @records, "#{model.id}"
      @_save()
      model
      
    
    
    constructor: (@namespace, storage) ->
      @storage = storage ? window.localStorage
      records = @storage.getItem @namespace
      @records = if records then records.split ',' else []
      
    
    
  
  
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
  

