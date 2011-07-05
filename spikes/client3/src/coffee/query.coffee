### ...
###
namespace 'query', (exports) ->
  
  templates = 
    title_bar: _.template """<%= title %>"""
  
  class Query extends Backbone.Model
  
  class QueryPage extends Backbone.View
    
    ### Setup the page elements.
    ###
    initialize: ->
      _.bindAll this, 'render'
      @query = @options.query
      @location = @options.location
      @query.bind 'change', @render
      @location.bind 'change', @render
      @location_button = new location.LocationButton
        el: $ '#location-button'
        model: @location
      # search
      # menu bar
      # etc.
    
    ### Update the query view.
    ###
    render: ->
      if @location.has('bbox')
        # XXX ping the api to get messages
        messages = [
            id: 'msg-1'
            content: 'message 1'
          , 
            id: 'msg-2'
            content: 'message 2'
        ]
        # update the title bar
        query_value = @query.get 'value'
        title_bar = @$ '.title-bar'
        if query_value
          title_bar.html templates.title_bar title: query_value
          title_bar.show()
        else
          title_bar.hide()
        # update the main window
        # XXX
        main_window = @$ '.main-window'
        main_window.html ''
        for item in messages
          m = new message.Message item
          v = new message.MessageEntry model: m
          main_window.append v.el
        # XXX scroll to the appropriate point
      else
        console.log 'missing query or location'
      
    
  
  exports.Query = Query
  exports.QueryPage = QueryPage
  

