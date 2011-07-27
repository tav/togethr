# `togethr.dialog` provides `Backbone.View` classes that render and apply dynamic
# behaviour to dialog pages providing a form based user interface.
# 
# So far we have:
# 
# * `LocationDialog` XXX rename
# 
# We need to add dialogs to:
# 
# * manage bookmarks
# * jump
# * checkin
# * bookmark
# * sendMessage
mobone.namespace 'togethr.dialog', (exports) ->
  
  ### ``Dialog`` page with google map allowing user to set their location.
  ###
  class LocationDialog extends mobone.view.Dialog
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
            short_name = results[0].address_components[0].short_name
            label = @$ '.location-label-input'
            label.val short_name.toLowerCase()
            # close the keyboard by losing focus
            target.blur()
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
      valid = togethr.model.Location.validId.test value
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
      instance = @locations.create
        id: value
        latitude: ll.lat()
        longitude: ll.lng()
      instance.save()
      @locations.select value
      window.history.back()
      false
      
    
    
    handleCancel: =>
      history.back()
      false
      
    
    
  
  exports.LocationDialog = LocationDialog
  
