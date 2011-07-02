### Models i) keep state and ii) fetch, save and manipulate data.
###
$.namespace 'model', (exports) ->
  
  LOCATION_LEVELS = [
    'neighborhood', 
    'sublocality', 
    'administrative_area_level_3', 
    'locality'
  ]
  
  ### model.Location (needs to be rethought, e.g.: keep a collection of locations,
    where is this persisted, etc.)
  ###
  exports.Location = Backbone.Model.extend 
    initialize: ->
      if not this.get "location"
        this.getLocation()
    
    getLocation: ->
      $.geolocation.find (location) => this.store location,
        -> alert "no location: app must explode in balls of flame"
    
    store: (location) ->
      geocoder = new google.maps.Geocoder
      ll = new google.maps.LatLng location.latitude, location.longitude
      geocoder.geocode latLng: ll, (results, status) =>
        if status is google.maps.GeocoderStatus.OK
          label = this._getLabel(results)
        else
          label = false
        this._setLocation(location, label)
    
    _getLabel: (results) ->
      for level in LOCATION_LEVELS
        for result in results
          for component in result.address_components
            if level in component.types
              return component.long_name
      return false
    
    _setLocation: (location, label) ->
      this.set
        location: location
        label: label or "#{location.latitude},#{location.longitude}"
      this.view.render()
    
  
  ### model.Search
  ###
  exports.Search = Backbone.Model.extend {}
  
  ### model.User
  ###
  
  ### model.Bookmark
  ###
  
  # etc. ...

