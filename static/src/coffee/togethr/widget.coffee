# `togethr.widget` provides `Backbone.View` classes that render and apply dynamic
# behaviour to user interface widgets shared across pages and dialogs:
# 
# * `SearchBar`, `TitleBar` and `LocationBar`
# * `MessageEntry`
# * `ActivityStream` (soon add to that `Map`, `ReplyStream` and `UserSummary`)
# * `FooterWidget`
mobone.namespace 'togethr.widget', (exports) ->
  
  class TogethrBar extends mobone.view.Widget
    initialize: ->
      @collection.bind 'selection:changed', @render
      
    
    render: =>
      target = @$ '#location-button .ui-btn-text'
      target.text @collection.selected.get 'id'
      
    
    
  
  class SearchBar extends mobone.view.Widget
    initialize: -> 
      @search_input = @$ '#search-input'
      @search_input.textinput theme: 'c'
      
    
    
  
  class TitleBar extends mobone.view.Widget
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
      
    
    
  
  class LocationBar extends mobone.view.Widget
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
      @slider.closest('.slider').bind 'touchstart mousedown', =>
        $('body').one 'touchend mouseup', @notify
      # when the jquery mobile code forces the handle to receive focus
      # make sure the scroll is flagged up
      @$('.ui-slider-handle').bind 'focus', -> $(document).trigger 'silentscroll'
      
    
    
    _toDistance: (value) ->
      @n * Math.pow value, @p
      
    
    _toValue: (distance) ->
      Math.pow distance/@n, 1/@p
      
    
    
    notify: =>
      v = @slider.val()
      d = @_toDistance v
      console.log "notify: slider value #{parseInt v}, distance #{parseInt d}km"
      @model.set value: d
      true
      
    
    update: =>
      d = @model.get 'value'
      v = @_toValue d
      console.log "update: distance #{parseInt d}km, slider value #{parseInt v}"
      @slider.val(v).slider 'refresh'
      true
      
    
    
  
  exports.TogethrBar = TogethrBar
  exports.SearchBar = SearchBar
  exports.TitleBar = TitleBar
  exports.LocationBar = LocationBar
  
  
  class MessageEntry extends Backbone.View
    className: 'message-entry'
    template: mobone.string.templateFromId 'message-listing-template'
    
    # Record when and where the touch start event was triggered
    handleTouchStart: (event) => 
      @touch_started = 
        ts: +new Date
        x: event.pageX
        y: event.pageY
      
    
    # When touch end fires, if its within 2 seconds and in the same place, show
    # the message.
    handleTouchEnd: (event) =>
      # we're only interested if touch start has been recorded
      return true if not @touch_started?
      # within 0.5 seconds
      ts = +new Date
      if ts - 500 > @touch_started.ts
        @touch_started = null
        return true
      # in the same place
      x = event.pageX
      y = event.pageY
      if not (x is @touch_started.x and y is @touch_started.y)
        @touch_started = null
        return true
      # and the event didn't come from a link (e.g.: an autolinked username, etc.)
      if $(event.target).closest('a').length > 0
        @touch_started = null
        return true
      # show the mesage
      @showMessage(event)
      false
    
    
    # Slide left to reveal the message.
    showMessage: (event) =>
      console.log "showMessage #{@model.id} #{event.type}"
      url = "/message/#{@model.id}"
      app.navigate url, true
      false
      
    
    # Slide right to reveal the message's parent (if it has one)
    showParent: (event) => console.log "XXX showParent not implemented"
    
    render: =>
      context =
        id: @model.id
        content: @model.get 'content'
      $(@el).html @template context
      
    
    initialize: ->
      @model.bind 'change', @render
      @render()
      target = $(@el)
      target.bind 'vmousedown', @handleTouchStart
      target.bind 'vmouseup', @handleTouchEnd
      target.bind 'swipeleft', @showMessage
      target.bind 'swiperight', @showParent
      
    
    
  
  exports.MessageEntry = MessageEntry
  
  
  # `ActivityStream` is a `ResultsView` showing a stream of action messages.
  class ActivityStream extends mobone.view.Widget
    
    # When a `message` is added to `@results`, render a `MessageEntry` and trigger
    # a `messages:added` event.
    handleAdd: (message) =>
      # Prepend a `MessageEntry` to the stream.
      entry = new MessageEntry model: message
      @el.prepend entry.el
      # Notify that the message was added.
      $(document).trigger 'messages:added', models: [message]
      
    
    # When `@results` is reset, clear the previous messages, render a `MessageEntry`
    # for each result and trigger a `messages:added` event.
    handleReset: =>
      # Clear the previous messages.
      @el.html ''
      # For each message, prepend a `MessageEntry` to the stream.
      messages = @results.models
      elements = []
      for message in messages
        entry = new MessageEntry model: message
        elements.push entry.el
      elements.reverse()
      @el.prepend elements
      # Notify that the messages were added.
      $(document).trigger 'messages:added', models: messages
      
    
    
    # When we recieve new results data, reset `@results` and, if necessary,
    # update `@context.get('distance')`.
    handleSuccess: (data) =>
      console.log 'handleResults', data
      @results.reset data.results
      # If the distance has changed (bc the backend took over and found the
      # optimum range) ...
      distance = @context.get('distance')
      if not (distance.get 'value' is data.distance)
        # ... update the distance, using a flag to avoid triggering a new 
        # distance query.
        @ignore_set_distance = true
        distance.set 'value': data.distance
      
    
    # If the query fails, do XXX.
    handleError: => console.log 'XXX getMessages failed.'
    
    # Make an ajax request to GET `/api/messages` from the server.
    getMessages: (include_distance) ->
      data = @query.toJSON()
      location = @locations.selected
      data.ll = "#{location.get 'latitude'},#{location.get 'longitude'}"
      data.distance = @distance.get 'value' if include_distance?
      $.ajax
        url: '/api/messages'
        data: data
        dataType: 'json'
        success: @handleSuccess
        error: @handleError
      
    
    
    # When `@context.get 'query'` changes make a request to get messages without
    # including a distance.
    handleQueryChange: => 
      @getMessages false
      
    
    # When `@context.get 'distance'` changes, as long as we didn't trigger it,
    # make a request to get messages with a specific distance included.
    handleDistanceChange: =>
      if @ignore_set_distance
        @ignore_set_distance = false
        return
      @getMessages true
      
    
    
    # Unbind from change events and record the current `@query` and `@distance`.
    snapshot: =>
      @query.unbind 'change', @handleQueryChange
      @distance.unbind 'change', @handleDistanceChange
      @previous_query = @query
      @previous_distance = @distance
      
    
    # Bind to change events, handle results if provided else get messages if
    # anything has changed.
    restore: =>
      # Bind to change events.
      @query.bind 'change', @handleQueryChange
      @distance.bind 'change', @handleDistanceChange
      # Handle results if provided.
      @__initial_data = @context.get '__initial_data'
      @context.unset '__initial_data'
      if @__initial_data?
        @handleResults @__initial_data 
      else # Get messages if anything has changed.
        if @previous_query? and not _.isEqual @query, @previous_query
          @handleQueryChange()
        else if @previous_distance? and not _.isEqual @distance, @previous_distance
          @handleDistanceChange() 
        
      
    
    
    # Unpack `@options.context`, create `@results`, bind to `add` and `reset`
    # events and trigger a `@restore()`.
    initialize: ->
      @context = @options.context
      @query = @context.get 'query'
      @distance = @context.get 'distance'
      @locations = @context.get 'locations'
      @results = new Backbone.Collection model: togethr.model.Message
      @results.bind 'add', @handleAdd
      @results.bind 'reset', @handleReset
      @restore()
      
    
    
  
  class ReplyStream extends mobone.view.Widget
  
  exports.ActivityStream = ActivityStream
  exports.ReplyStream = ReplyStream
  
  
  class FooterWidget extends mobone.view.Widget
    initialize: ->
      bar = @$ '.menu-bar'
      bar.navbar()
      act_button = new mobone.view.RelativeButton
        el: @$ '.act-button a'
      
    
  
  exports.FooterWidget = FooterWidget
  
  


