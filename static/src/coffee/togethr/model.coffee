# `togethr.model` provides `Backbone.Model` and `Backbone.Collection` classes
# that store data and encapsulate the client application's state:
# 
# * `Bookmark` and `Bookmarks` encapsulate a user's bookmarked shortcuts
# * `Location` and `Locations` encapsulate the `+location`s a user has defined
# * `Here` is a special `Location` that tracks the navigator.geolocation
# * `Query` encapsulate the current search query
# * `Message` and `Messages` encapsulate action messages and replies
# * `User` and `Users` encapsulate `@user`s
#
# When implemented, will also provide `Space`, `Spaces`, `Badge` and `Badges`.
namespace 'togethr.model', (exports) ->
  
  # `Bookmark` is a named shortcut to specific context.
  class Bookmark extends mobone.model.ServerBackedLocalModel
    storage_name: 'bookmarks'
    track_changes: true
    urlRoot: '/api/bookmark'
    
  # `Bookmarks` is a collection of `Bookmark`s.
  class Bookmarks extends mobone.model.ServerBackedLocalCollection
    storage_name: 'bookmarks'
    track_changes: true
    url: '/api/bookmarks'
    model: Bookmark
    
  
  exports.Bookmark = Bookmark
  exports.Bookmarks = Bookmarks
  
  
  # `Location` is a named latitude and longitude, i.e.: a point with a label.
  class Location extends mobone.model.ServerBackedLocalModel
    storage_name: 'locations'
    track_changes: true
    urlRoot: '/api/location'
    
    @validId: /^\+.*/ # XXX potentially expand this when addressing escaping
    validate: (attrs) ->
      if attrs
        # make sure the id is lowercase and starts with a '+'
        if attrs.id?
          id = attrs.id
          return 'id must be lowercase' if id.toLowerCase() is not id
          return 'id must start with "+"' if not (id.charAt(0) is '+')
          return 'invalid id' if not @constructor.validId.test id
        # make sure the latitude and longitude are valid numbers
        if attrs.latitude?
          lat = attrs.latitude
          return 'latitude must be a number' if not (typeof lat is 'number')
          return '-90 <= latitude <= 90' if not (-90 <= lat <= 90)
        if attrs.longitude?
          lng = attrs.longitude
          return 'longitude must be a number' if not (typeof lng is 'number')
          return '-180 <= longitude <= 180' if not (-180 <= lng <= 180)
      
    
    toLatLng: ->
      lat = @get 'latitude'
      lng = @get 'longitude'
      new google.maps.LatLng lat, lng
      
    
    
  
  # `Here is a special `Location` that tracks the user's current geolocation.
  class Here extends mobone.model.LocalModel
    storage_name: 'here'
    track_changes: true
    expires_after: 30 # minutes
    
    # is the data recent?
    isRecent: ->
      date_string = @get 'modified'
      if date_string?
        # t1 is when last stored
        t1 = new Date date_string
        # t2 is now
        t2 = new Date
        # add ``expires_after`` mins to t1
        t1.setMinutes t1.getMinutes() + @expires_after
        # if it's greater than t2, the date is recent
        return true if t1 > t2
      false
      
    
    # update model attributes and save to short lived cookie
    storeLocation: (coords, silent) ->
      # update model attributes
      d = new Date
      attrs =
        latitude: coords.latitude
        longitude: coords.longitude
        modified: d.toUTCString()
      @set attrs, silent: silent
      @save()
      
    
    # start monitoring location, storing changes
    startWatching: (silently) ->
      options =
        enableHighAccuracy: true
        watch: true
      $.geolocation.find (coords) => 
          @storeLocation coords, silently
        , $.noop
        , options
      
    
    # get current location and then ``startWatching``
    start: (callback, silentTracking) ->
      # default silent to true
      silentTracking or= true
      # fetch the current location
      $.geolocation.find (coords) =>
          this.storeLocation coords, false
          @startWatching silentTracking
          callback true
        , -> 
          callback false
        , enableHighAccuracy: true
      
    
    
  Here.validId = Location.validId
  _.extend Here.prototype,
    validate: Location.prototype.validate
    toLatLng: Location.prototype.toLatLng
  
  # `Locations` is a collection of `Location`s.  Provides a `@selected`
  # `Location`, which defaults to `Here`.  Fires `selection:changed` when the
  # selected `Location` changes.
  class Locations extends mobone.model.ServerBackedLocalCollection
    storage_name: 'locations'
    track_changes: true
    url: '/api/locations'
    model: Location
    
    # select a model by id and notify that the selected model has changed
    select: (id, opts) ->
      @selected = @get id
      if not (opts? and opts.silent is true)
        @trigger 'selection:changed', @selected 
      
    
    # select +here by default
    initialize: ->
      super
      @selected = @get '+here'
      
    
    
  
  exports.Location = Location
  exports.Here = Here
  exports.Locations = Locations
  
  
  # `Query` encapsulate the current search query.
  class Query extends Backbone.Model
    # XXX todo: parse query string into structured dict
  
  exports.Query = Query
  
  
  # `Message` encapsulates a message.
  class Message extends Backbone.Model
  
  # `Messages` is a collection that contains upto the 300 most recent `Message`s.
  class Messages extends mobone.model.RecentInstanceCache
    model: Message
    limit: 300
  
  exports.Message = Message
  exports.Messages = Messages
  
  
  # `User` encapsulates a `@user`.
  class User extends Backbone.Model
  
  # `Users` is a collection that contains upto the 20 most recent `User`s.
  class Users extends mobone.model.RecentInstanceCache
    model: User
    limit: 20
  
  exports.User = User
  exports.Users = Users
  
  

