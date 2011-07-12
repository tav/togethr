### ...
###
namespace 'query', (exports) ->
  
  class Query extends Backbone.Model
  
  class TitleBar extends baseview.Widget
    initialize: -> 
      @model.bind 'change', @render
      
    
    render: => 
      value = decodeURIComponent @model.get 'value'
      @$('.title').text value
      if value
        @el.show()
      else 
        @el.hide()
      
    
    
  
  class ActivityStream extends baseview.Widget
    initialize: ->
      console.log 'ActivityStream', @collection
      @collection.bind 'add', @handleAdd
      @collection.bind 'reset', @handleReset
      
    
    handleAdd: =>
      @el.append message.view.el
      
    
    handleReset: =>
      @el.html ''
      @collection.each (message) => @el.append message.view.el
      
    
    
  
  class QueryPage extends baseview.Page
    
    ignore_set_distance: false
    
    initialize: ->
      
      @query = @options.query
      @locations = @options.locations
      
      @messages = new message.Messages
      @distance = new Backbone.Model
      
      @location_bar = new location.LocationBar
        el: @$ '.location-bar'
        model: @distance
      
      @title_bar = new TitleBar
        el: @$ '.title-bar'
        model: @query
      
      @results_view = new ActivityStream
        el: @$ '.main-window'
        collection: @messages
      
      @query.bind 'change', @performQuery
      @locations.bind 'selection:changed', @performQuery
      @distance.bind 'change', @performDistanceQuery
      
    
    
    handleResults: (query_value, results, distance) =>
      console.log 'QueryPage.handleResults', results.length
      # update the messages, which triggers @results_view to render
      items = (new message.Message item for item in results)
      @messages.reset items
      # update the distance, which triggers @location_bar
      # using a flag to avoid triggering a distance query
      @ignore_set_distance = true
      @distance.set 'value': distance
      # scroll and blur to finish
      y = if query_value then @title_bar.el.offset().top else 1
      $.mobile.silentScroll y
      window.setTimeout -> 
          $(document.activeElement).blur()
        , 0
      
    
    fetchMessages: (query_value, latlng, distance, success, failure) =>
      ### XXX this is fake
      ### 
      a = Math.random()
      b = Math.random()
      results = [
          id: "msg-#{a}"
          content: "Message #{a}"
        , 
          id: "msg-#{b}"
          content: "Message #{b}"
      ]
      distance = distance ? Math.sqrt(Math.random() * 10000)
      success query_value, results, distance
      
    
    
    performQuery: =>
      query_value = @query.get 'value'
      latlng = @locations.selected.toJSON()
      # XXX
      @fetchMessages query_value, latlng, null, @handleResults, -> 
          alert 'could not fetch messages'
        
      
    
    performDistanceQuery: =>
      if @ignore_set_distance
        @ignore_set_distance = false
        return
      console.log 'QueryPage.performDistanceQuery'
      query_value = @query.get 'value'
      distance = @distance.get 'value'
      latlng = @locations.selected.toJSON()
      # XXX
      @fetchMessages query_value, latlng, distance, @handleResults, -> 
          alert 'could not fetch messages'
        
      
      
    
    
  
  exports.Query = Query
  exports.QueryPage = QueryPage
  

