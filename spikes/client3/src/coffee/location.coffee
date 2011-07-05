### ...
###
namespace 'location', (exports) ->
  
  class Location extends Backbone.Model
  
  class LocationButton extends Backbone.View
    
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
      app.navigate 'location', true
      
    
    
  
  exports.Location = Location
  exports.LocationButton = LocationButton
  

