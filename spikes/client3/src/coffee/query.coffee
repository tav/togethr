### ...
###
namespace 'query', (exports) ->
  
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
      
      @scroll = @$ '.scroll'
      @title_bar = @$ '.title-bar'
      @title_el = $ '.title', @title_bar
      @main_window = @$ '.main-window'
      
      @query.bind 'change', @rerender
      @location.bind 'change', @rerender
      
      @location_button = new location.LocationButton
        el: $ '#location-button'
        model: @location
      # search
      # menu bar
      # etc.
      
      # make sure when scrolling we don't have floating cursors
      # from inputs in focus
      @scroll.bind 'touchstart', -> $(document.body).focus()
      # setup scrolling
      @scroll.touchScroll
        touchTags: ['a', 'button', 'input', 'select', 'textarea']
      
      @render()
      
    
    
    ### ...
    ###
    render: =>
      console.log 'Query.render'
      # XXX this should all be component'd out
      query_value = @query.get 'value'
      if query_value
        @title_el.text query_value
        @title_bar.show()
      else
        @title_bar.hide()
      # update the main window
      @main_window.html ''
      @messages.each (message) => @main_window.append message.view.el
      # refresh scrolling
      @scroll.touchScroll 'update'
      # XXX scroll to the appropriate point
      if query_value
        offset = @title_bar.offset()
        @scroll.touchScroll 'setPosition', offset.top
      else
        @scroll.touchScroll 'setPosition', 0
      window.setTimeout ->
          $(document.activeElement).blur()
        ,
        0
      
      
    
    
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
  

