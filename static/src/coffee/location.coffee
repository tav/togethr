### ...
###
namespace 'location', (exports) ->
  
  ### ``Model`` class that encapsulates a specific location.
  ###
  class Location extends Backbone.Model
    
    @validId: /^\+.*/ # XXX potentially expand this when addressing escaping
    
    localStorage: new Store 'locations'
    
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
    ### Works like this:
      
      Select an existing location
        -> goes straight to homepage
      
      Define a new location
        -> on search
          -> update map
          -> update label
        -> on map move
          -> clear label
        -> on save
          -> flag if label missing
          -> flag if label exists
          
      n.b.: in future could also have
      
        -> on label focus
          present autocomplete suggestions from google api
      
    ###
    
    events:
      'change .existing-location-select'                : 'handleSelect'
      'submit .location-search-form'                    : 'handleSearch'
      'vclick .save-button'                             : 'handleSave'
      'vclick .cancel-button'                           : 'handleCancel'
    
    initialize: ->
      @locations = @options.locations
      node = @$('.map').get 0
      options = 
        mapTypeId: google.maps.MapTypeId.ROADMAP
        disableDefaultUI: true
        zoomControl: true
        zoom: 12
      @geocoder = new google.maps.Geocoder
      @map = new google.maps.Map node, options
      url = 'build/gfx/crosshair.png'
      size = new google.maps.Size 240, 180
      origin = new google.maps.Point 0, 0
      anchor = new google.maps.Point 120, 90
      icon = new google.maps.MarkerImage url, size, origin, anchor
      @crosshair = new google.maps.Marker
        map: @map
        icon: icon
        shape:
          coords: [0,0,0,0]
          type: 'rect'
      @crosshair.bindTo 'position', @map, 'center'
      google.maps.event.addListener @map, 'dragstart', => @crosshair.setVisible false
      google.maps.event.addListener @map, 'dragend', => @crosshair.setVisible true
      google.maps.event.addListener @map, 'dragend', @clearLabel
      
    
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
      
    
    positionCrossHair: =>
      @crosshair.setPosition @map.getCenter()
      
    
    centreMap: =>
      latlng = @locations.selected.toLatLng()
      console.log latlng
      @map.setCenter latlng
      
    
    clearLabel: =>
      target = @$ '.location-label-input'
      target.val ''
      container = target.closest('.ui-field-contain')
      container.removeClass 'error' if container.hasClass 'error'
      label = $ 'label', container
      label.text 'Give this location a short name:'
      
    
    clearSearch: =>
      target = @$ '.location-search-input'
      target.val ''
      
    
    render: =>
      @updateExistingLocationsSelect()
      @updateMapContainerDimensions()
      @centreMap()
      @clearSearch()
      @clearLabel()
      
    
    
    handleSelect: =>
      target = @$ '.existing-location-select'
      value = target.val()
      console.log 'handleSelect', value
      @locations.select value
      window.history.back()
      false
      
    
    handleSearch: =>
      target = @$ '.location-search-input'
      value = target.val()
      console.log value
      @geocoder.geocode address: value, (results, status) =>
          if status is google.maps.GeocoderStatus.OK
            # centre the map
            geometry = results[0].geometry
            @map.fitBounds geometry.bounds
            # update the label input
            label = results[0].address_components[0].short_name
            target = @$ '.location-label-input'
            target.val label.toLowerCase()
          else
            console.warning status if console? and console.warning?
      false
      
    
    handleSave: =>
      target = @$ '.location-label-input'
      container = target.closest('.ui-field-contain')
      label = $ 'label', container
      value = target.val()
      if not value
        container.addClass 'error'
        label.text 'You must give this location a short name:'
        return false
      value = "+#{value.toLowerCase()}"
      valid = Location.validId.test value
      if not valid
        container.addClass 'error'
        label.text 'That\'s not a valid name for a location:'
        return false
      ll = @map.getCenter()
      existing = @locations.get value
      if existing
        if existing.latitude is ll.lat() and existing.latitude is ll.lng()
          @locations.select value
          window.history.back()
          return false
        else
          container.addClass 'error'
          label.text 'You already have a location with this name:'
          return false
      instance = new location.Location
        id: value
        latitude: ll.lat()
        longitude: ll.lng()
      instance.save()
      @locations.add instance
      @locations.select value
      window.history.back()
      false
      
    
    
    handleCancel: =>
      history.back()
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
  


