(
  ($) ->
    
    Location = Backbone.Model.extend
      _levels: [
        'neighborhood', 
        'sublocality', 
        'administrative_area_level_3', 
        'locality'
      ]
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
        for level in this._levels
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
      
    
    LocationView = Backbone.View.extend
      el: $ '#location-button'
      events:
        click: 'changeLocation'
      initialize: ->
        _.bindAll this, 'render', 'changeLocation'
        this.model.bind 'change', this.render
        this.model.view = this
      
      render: ->
        $ this.el .text "+#{this.model.get 'label'}"
        return this
      
      changeLocation: ->
        alert 'show set location dialog ...'
      
    
    location = new Location
    location_button = new LocationView
      model: location
    
  
)(jQuery)