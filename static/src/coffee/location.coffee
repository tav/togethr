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
    
    toLatLng: ->
      lat = @get 'latitude'
      lng = @get 'longitude'
      new google.maps.LatLng lat, lng
      
    
  
  
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
      latitude: 51.5197
      longitude: -0.1408
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
      @selected = @getByLabel '+here'
      
    
    
  
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
      @locations = @options.locations
      options = 
        mapTypeId: google.maps.MapTypeId.ROADMAP
        disableDefaultUI: true
        zoomControl: true
        zoom: 12 # XXX derived from distance?
      @map = new google.maps.Map @$('.map').get(0), options
      
    
    
    snapshot: ->
      @locations.unbind 'selection:changed', @render
      $(window).unbind 'throttledresize orientationchange', @updateMapContainerDimensions
      
    
    restore: ->
      @locations.bind 'selection:changed', @render
      $(window).bind 'throttledresize orientationchange', @updateMapContainerDimensions
      setTimeout @render, 0
      
    
    
    updateMapContainerDimensions: =>
      target = @$ '.map'
      target.height(@el.width() * 9 / 16)
      google.maps.event.trigger @map, 'resize'
      
    
    centreMap: =>
      latlng = @locations.selected.toLatLng()
      @map.setCenter latlng
      
    
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
  exports.LocationDialog = LocationDialog
  exports.SelectExistingLocationDialog = SelectExistingLocationDialog
  


