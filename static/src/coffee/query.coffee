### ...
###
namespace 'query', (exports) ->
  
  class Query extends Backbone.Model
  
  class SearchBar extends baseview.Widget
    initialize: -> 
      @search_input = @$ '#search-input'
      @search_input.textinput theme: 'c'
      
    
    
  
  class TitleBar extends baseview.Widget
    initialize: -> 
      @model.bind 'change', @render
      
    
    render: => 
      value = decodeURIComponent @model.get 'value'
      value = value.replace /\+/g, ' '
      @$('.title').text value
      if value
        @el.show()
      else 
        @el.hide()
      
    
    
  
  class LocationBar extends baseview.Widget
    
    ignore_slide_change: false
    
    notify_delay: 250
    notify_pending: null
    
    n: 64999 / 100000000000000000
    p: 8
    
    initialize: ->
      # init the jquery.mobile slider
      @slider = @$ '#location-slider'
      @slider.slider theme: 'c'
      # when @distance changes, update the slider
      @model.bind 'change', @update
      # when the slider changes, update the distance
      @slider.closest('.slider').bind 'vclick scrollstop mouseup', @notify
      # when the jquery mobile code forces the handle to receive focus
      # make sure the scroll is flagged up
      handle = @$ '.ui-slider-handle'
      handle.bind 'focus', -> 
        $(document).trigger 'silentscroll'
      
    
    
    _toDistance: (value) ->
      @n * Math.pow value, @p
      
    
    _toValue: (distance) ->
      Math.pow distance/@n, 1/@p
      
    
    
    notify: =>
      v = @slider.val()
      d = @_toDistance v
      #console.log "notify: slider value #{parseInt v}, distance #{parseInt d}km"
      @model.set value: d
      true
      
    
    update: =>
      d = @model.get 'value'
      v = @_toValue d
      #console.log "update: distance #{parseInt d}km, slider value #{parseInt v}"
      @slider.val(v).slider 'refresh'
      true
      
    
    
  
  class ActivityStream extends baseview.Widget
    initialize: ->
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
      
      @search_bar = new SearchBar
        el: @$ '.search-bar'
      
      @title_bar = new TitleBar
        el: @$ '.title-bar'
        model: @query
      
      @location_bar = new LocationBar
        el: @$ '.location-bar'
        model: @distance
      
      @results_view = new ActivityStream
        el: @$ '.main-window'
        collection: @messages
      
      @query.bind 'change', @performQuery
      @locations.bind 'selection:changed', @performQuery
      @distance.bind 'change', @performDistanceQuery
      
    
    
    handleResults: (query_value, results, distance) =>
      # update the messages, which triggers @results_view to render
      items = (new message.Message item for item in results)
      @messages.reset items
      # if the distance has changed (bc the backend took over and found the
      # optimum range)
      the_same = @distance.get('value') is distance
      if not the_same
        # update the distance, which triggers @location_bar
        # using a flag to avoid triggering a distance query
        @ignore_set_distance = true 
        @distance.set 'value': distance
      # scroll and blur to finish
      y = 1 # if query_value then @title_bar.el.offset().top else 1
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
      r = Math.random()
      distance = distance ? Math.sqrt(r * r * r * 100000)
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
      query_value = @query.get 'value'
      distance = @distance.get 'value'
      latlng = @locations.selected.toJSON()
      # XXX
      @fetchMessages query_value, latlng, distance, @handleResults, -> 
          alert 'could not fetch messages'
        
      
      
    
    
  
  exports.Query = Query
  exports.QueryPage = QueryPage
  

