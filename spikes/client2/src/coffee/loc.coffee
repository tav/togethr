$.namespace 'loc', (exports) ->
  
  class Location extends Backbone.Model
  
  class LocationView extends Backbone.View
    
    events:
      click: 'changeLocation'
    
    initialize: ->
      _.bindAll this, 'render', 'changeLocation'
      @model.bind 'change', @render
      @model.view = this
      @render()
    
    render: ->
      $ @el .text "+#{@model.get 'label'}"
      
    
    changeLocation: ->
      $.mobile.changePage '#location'
      false
    
  
  exports.Location = Location
  exports.LocationView = LocationView
  

