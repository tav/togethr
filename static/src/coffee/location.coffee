### ...
###
namespace 'location', (exports) ->
  
  ### ``Model`` class that encapsulates a specific location.
  ###
  class Location extends Backbone.Model
    
    localStorage: new Store 'locations'
    
    toLatLng: ->
      lat = @get 'latitude'
      lng = @get 'longitude'
      new google.maps.LatLng lat, lng
      
    
  
  ### Special ``Location`` class that tracks the user's current geolocation.
  ###
  class Here extends Location
    
    localStorage: new Store 'here'
    
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
      
    
    
  
  ### ``Location``s collection.
  ###
  class Locations extends Backbone.Collection
    
    model: Location
    localStorage: new Store 'locations'
    
    # select a model by id and notify that the selected model has changed
    select: (id, opts) ->
      @selected = @get id
      if not (opts? and opts.silent is true)
        @trigger 'selection:changed', @selected 
      
    
    
    # select +here by default
    initialize: ->
      @selected = @get '+here'
      
    
    
  
  ### ``Dialog`` page with google map allowing user to set their location.
  ###
  class LocationDialog extends baseview.Dialog
    
    events:
      'change .existing-location-select'                : 'handleSelect'
      'submit .location-search-form'                    : 'handleSearch'
      'vclick .label-suggestion'                        : 'handleSelectLabel'
      'vclick .save-button'                             : 'handleSave'
      'vclick .cancel-button'                           : 'handleCancel'
    
    initialize: ->
      @locations = @options.locations
      options = 
        mapTypeId: google.maps.MapTypeId.ROADMAP
        disableDefaultUI: true
        zoomControl: true
        zoom: 12 # XXX derived from distance?
      @map = new google.maps.Map @$('.map').get(0), options
      @geocoder = new google.maps.Geocoder
      
    
    
    snapshot: ->
      @locations.unbind 'selection:changed', @render
      $(window).unbind 'throttledresize orientationchange', @updateMapContainerDimensions
      
    
    restore: ->
      @locations.bind 'selection:changed', @render
      $(window).bind 'throttledresize orientationchange', @updateMapContainerDimensions
      setTimeout @render, 0
      
    
    
    updateExistingLocationsSelect: =>
      target = @$ '.existing-location-select'
      options = []
      @locations.each (item) =>
        id = item.get 'id'
        if id
          if item is @locations.selected
            options.push "<option value=\"#{id}\" selected=\"true\">#{id}</option>"
          else
            options.push "<option value=\"#{id}\">#{id}</option>"
      
      target.html options.join ''
      target.selectmenu 'refresh', true
      # don't let vclicks bubble
      target.closest('.ui-select').bind 'vclick', -> false
      
    
    
    updateMapContainerDimensions: =>
      target = @$ '.map'
      target.height(@el.width() * 9 / 16)
      google.maps.event.trigger @map, 'resize'
      
    
    
    centreMap: =>
      latlng = @locations.selected.toLatLng()
      @map.setCenter latlng
      
    
    
    render: =>
      @updateExistingLocationsSelect()
      @updateMapContainerDimensions()
      @centreMap()
      
    
    
    handleSelect: =>
      target = @$ '.existing-location-select'
      value = target.val()
      console.log 'handleSelect', value
      @locations.select value
      false
      
    
    
    handleSearch: =>
      target = @$ '.location-search-input'
      value = target.val()
      console.log value
      @geocoder.geocode address: value, (results, status) =>
          if status is google.maps.GeocoderStatus.OK
            geometry = results[0].geometry
            @map.fitBounds geometry.bounds
          else
            console.warning status if console? and console.warning?
      false
      
    
    
    handleSelectLabel: =>
      
    
    handleSave: =>
      target = @$ '.location-search-input'
      label = prompt 'Please give this location a short name', target.val()
      if label
        latlng = @map.getCenter()
        instance = new location.Location
          id: label
          latitude: latlng.lat()
          longitude: latlng.lng()
        # XXX this just errors on a dupe
        @locations.add instance
        @locations.select label
        history.go -1
      false
    
    handleCancel: =>
      history.go -1
      false
      
    
    
  
  ### Simple ``Dialog`` listing existing locations.
  ###
  class SelectExistingLocationDialog extends baseview.Dialog
    # XXX todo
    
  
  exports.Location = Location
  exports.Here = Here
  exports.Locations = Locations
  exports.LocationDialog = LocationDialog
  exports.SelectExistingLocationDialog = SelectExistingLocationDialog
  


