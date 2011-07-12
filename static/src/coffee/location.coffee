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
    
  
  ### ``Widget`` with location slider and set location button.
  ###
  class LocationWidget extends baseview.Widget
    
    initialize: ->
      @model.bind 'change', @render
      @render()
    
    render: =>
      # XXX update the display
      
    
    
  
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
  exports.LocationWidget = LocationWidget
  exports.LocationDialog = LocationDialog
  exports.SelectExistingLocationDialog = SelectExistingLocationDialog
  


