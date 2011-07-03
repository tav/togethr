### Views i) update the UI ii) register and handle events.
###
$.namespace 'view', (exports) ->
  
  ### view.LocationButton
  ###
  exports.LocationButton = Backbone.View.extend
    el: $ '#location-button'
    events:
      click: 'changeLocation'
    initialize: ->
      _.bindAll this, 'render', 'changeLocation'
      this.model.bind 'change', this.render
      this.model.view = this
      this.render()
    
    render: ->
      $ this.el .text "+#{this.model.get 'label'}"
      return this
    
    changeLocation: ->
      alert 'show set location dialog ...'
    
  

