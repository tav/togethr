### ...
###
namespace 'location', (exports) ->
  
  ### ``Model`` class that encapsulates a specific location.
  ###
  class Location extends Backbone.Model
    defaults:
      latitude: 0.0
      longitude: 0.0
      label: ''
    
  
  ### Special ``Location`` class that tracks the user's current geolocation.
  ###
  class Here extends Location
    ###
        # XXX HACK for testing
        $.geolocation.find = (cb) -> cb {latitude: 51.5197, longitude: -0.1408}
        # XXX END HACK
        
        # get the user's location
        $.geolocation.find (coords) ->
        
            # set ``here`` to the user's location
            here = new location.Location coords
        
    ###
    defaults:
      latitude: 0.0
      longitude: 0.0
      label: '+here'
    
    
  
  ### ``Location``s collection.
  ###
  class Locations extends Backbone.Collection
    
    # get the first model matching the provided label
    getByLabel: (label) -> 
      @find (item) -> item.get('label') is label
      
    
    # select a model by label and notify that the selected model has changed
    select: (label, opts) ->
      @selected = @getByLabel label
      if not (opts? and opts.silent is true)
        @trigger 'selection:changed', @selected 
      
    
    
    # select +here by default
    initialize: ->
      console.log 'new Locations', @models
      @selected = @getByLabel '+here'
      console.log '@selected', @selected
      
    
    
  
  class LocationBar extends baseview.Widget
    
    ignore_slide_change: false
    
    notify_delay: 250
    notify_pending: null
    
    n: 64999 / 100000000000000000
    p: 8
    
    initialize: ->
      # init the jquery.mobile slider
      @slider = @$ '#location-slider'
      @slider.slider theme: 'c'
      # when @distance changes, update the slider
      @model.bind 'change', @update
      # when the slider changes, update the distance
      @slider.closest('.slider').bind 'vclick scrollstop mouseup', @notify
      # when the jquery mobile code forces the handle to receive focus
      # make sure the scroll is flagged up
      handle = @$ '.ui-slider-handle'
      console.log 'handle', handle
      handle.bind 'focus', -> 
        console.log 'XXX HELLO! XXX'
        $(document).trigger 'silentscroll'
      
    
    _toDistance: (value) ->
      @n * Math.pow value, @p
      
    
    _toValue: (distance) ->
      Math.pow distance/@n, 1/@p
      
    
    
    notify: =>
      v = @slider.val()
      d = @_toDistance v
      console.log "notify: slider value #{parseInt v}, distance #{parseInt d}km"
      # XXX update the distance
      true
    
    
    update: =>
      d = @model.get 'value'
      v = @_toValue d
      console.log "update: distance #{parseInt d}km, slider value #{parseInt v}"
      @slider.val(v).slider 'refresh'
      true
      
    
    
  
  ### ``Dialog`` page with google map allowing user to set their location.
  ###
  class LocationDialog extends baseview.Dialog
    
    events:
      'vclick #select-existing-location-button'         : 'handleSelect'
      'submit .location-search-input'                   : 'handleSearch'
      'vclick .label-suggestion'                        : 'handleSelectLabel'
      'vclick .save-button'                             : 'handleSave'
      'vclick .cancel-button'                           : 'handleCancel'
    
    initialize: ->
      
      # XXX we've changed to using @locations
      
      @location = @options.location
      # render map
      node = @$('.map').get 0
      options = 
        mapTypeId: google.maps.MapTypeId.ROADMAP
        disableDefaultUI: true
        zoomControl: true
      @map = new google.maps.Map node, options
      @render()
      
    
    
    snapshot: ->
      @location.unbind 'change', @render
      $(window).unbind 'throttledresize orientationchange', @updateMapContainerDimensions
      
    
    restore: ->
      @location.bind 'change', @render
      $(window).bind 'throttledresize orientationchange', @updateMapContainerDimensions
      
    
    
    updateMapContainerDimensions: =>
      # XXX quite how to manage the dimensions of the map, I'm not sure...
      target = @$ '.map'
      h = window.innerHeight / 2
      h = 200 if h < 200
      target.height(h)
      google.maps.event.trigger @map, 'resize'
      
    
    centreMap: =>
      latlng = new google.maps.LatLng @location.latitude, @location.longitude
      @map.setCentre(latlng)
      
    
    
    render: =>
      @updateMapContainerDimensions()
      @centreMap()
      # update the label
      
    
    
    handleSelect: =>
      
    
    handleSearch: =>
      
    
    handleSelectLabel: =>
      
    
    handleSave: =>
      
    
    handleCancel: =>
      
    
    
  
  ### Simple ``Dialog`` listing existing locations.
  ###
  class SelectExistingLocationDialog extends baseview.Dialog
    # XXX todo
    
  
  exports.Location = Location
  exports.Here = Here
  exports.Locations = Locations
  exports.LocationBar = LocationBar
  exports.LocationDialog = LocationDialog
  exports.SelectExistingLocationDialog = SelectExistingLocationDialog
  


