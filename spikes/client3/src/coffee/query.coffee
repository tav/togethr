### ...
###
namespace 'query', (exports) ->
  
  templates = 
    title_bar: _.template """<%= title %>"""
  
  class Query extends Backbone.Model
    defaults:
      value: ''
    
  
  class QueryPage extends Backbone.View
    
    ### ...
    ###
    initialize: ->
      
      @user = @options.user
      @query = @options.query
      @messages = @options.messages
      @location = @options.location
      
      @query.bind 'change', @rerender
      @location.bind 'change', @rerender
      
      @location_button = new location.LocationButton
        el: $ '#location-button'
        model: @location
      # search
      # menu bar
      # etc.
      
      @render()
      
    
    
    ### ...
    ###
    render: =>
      console.log 'Query.render'
      # XXX this should all be component'd out
      query_value = @query.get 'value'
      title_bar = @$ '.title-bar'
      if query_value
        title_bar.html templates.title_bar title: query_value
        title_bar.show()
      else
        title_bar.hide()
      # update the main window
      main_window = @$ '.main-window'
      main_window.html ''
      @messages.each (message) -> main_window.append message.view.el
      # XXX scroll to the appropriate point
      
    
    
    ### XXX ping the api to get messages
    ### 
    fetchMessages: (success, failure) =>
      console.log 'Query.fetchMessages'
      a = Math.random()
      b = Math.random()
      results = [
          id: "msg-#{a}"
          content: "Message #{a}"
        , 
          id: "msg-#{b}"
          content: "Message #{b}"
      ]
      # call success with the fake results
      success results
      
    
    
    ### ...
    ###
    rerender: =>
      console.log 'Query.rerender'
      @fetchMessages (results) =>
          items = (new message.Message item for item in results)
          @messages.reset items
          @render()
        , ->
          alert 'could not fetch messages'
        
      
    
    
  
  exports.Query = Query
  exports.QueryPage = QueryPage
  

