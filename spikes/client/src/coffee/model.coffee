### `model` classes i) encapsulate state and ii) fetch, store and manipulate data.
###
$.namespace 'model', (exports) ->
  
  ### `model.User` encapsulates a user.
  ###
  User = Backbone.Model.extend
    defaults:
      is_authenticated: false
      is_admin: false
      username: 'guest'
      displayName: 'Guest User'
      profileImage: '...'
    
  ### `model.Settings` encapsulates the authenticated user's settings.
  ###
  Settings = Backbone.Model.extend
    # defaults: ???
  
  exports.User = User
  exports.Settings = Settings
  
  ### `model.Location` encapsulates a location.
  ###
  Location = Backbone.Model.extend
    defaults:
      lat: 0.0
      lon: 0.0
      bbox: []
      label: ''
      level: ''
    
    setToCurrent: (success, failure) ->
      $.geolocation.find (location) => 
          this.store location, success
        , failure
      
    
    store: (location, callback) ->
      geocoder = new google.maps.Geocoder
      ll = new google.maps.LatLng location.latitude, location.longitude
      geocoder.geocode latLng: ll, (results, status) =>
        if status is google.maps.GeocoderStatus.OK
          label = this._getLabel results 
        else
          label = false
        this._setLocation(location, label)
        callback()
      
    
    _levels: [
      'neighborhood', 
      'sublocality', 
      'administrative_area_level_3', 
      'locality'
    ]
    _getLabel: (results) ->
      for level in this._levels
        for result in results
          for component in result.address_components
            if level in component.types
              return component.long_name
      return false
      
    
    _setLocation: (location, label) ->
      this.set
        lat: location.latitude
        lon: location.longitude
        label: label or "#{location.latitude},#{location.longitude}"
      
    
  
  ### `model.Locations` is a collection of `model.Location`s.
  ###
  Locations = Backbone.Collection.extend
    model: Location
  
  exports.Location = Location
  exports.Locations = Locations
  
  ### `model.Space` encapsulates a cumulative set of filters.
  ###
  Space = Backbone.Model.extend
    defaults:
      user: {}
      challenge: {}
      hashtags: []
      keywords: []
    
  ### `model.ActionMessage` encapsulates an action message.
  ###
  ActionMessage = Backbone.Model.extend
    defaults:
      from_user: {}
      from_location: {}
      to_location: {}
      to_space: {}
      on: '' # XXX datetime?
      actions: []
      message: ''
      data: {} # XXX attachments?
    
  ### `model.Comment` encapsulates a comment.
  ###
  Comment = Backbone.Model.extend
    defaults:
      from_user: {}
      from_location: {}
      to_message: {}
      on: '' # XXX datetime?
      message: ''
      data: {} # XXX attachments?
    
  exports.Space = Space
  exports.ActionMessage = ActionMessage
  exports.Comment = Comment
  
  ### `model.Context` encapsulates a `Space` and `Location`.
  ###
  Context = Backbone.Model.extend
    defaults:
      location: {}
      space: {}
    
  ### `model.Contexts` is a collection of `model.Context`s.
  ###
  Contexts = Backbone.Collection.extend
    model: Context
  
  exports.Context = Context
  exports.Contexts = Contexts
  
  ### `model.Bookmark` encapsulates a persistent, aliased context.
  ###
  Bookmark = Backbone.Model.extend
    defaults:
      context: {}
      alias: ''
    
  ### `model.Bookmarks` is a collection of `model.Bookmark`s.
  ###
  Bookmarks = Backbone.Collection.extend
    model: Bookmark
  
  exports.Bookmark = Bookmark
  exports.Bookmarks = Bookmarks
  

