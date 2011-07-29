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
  
  
  # `ResultsView` is an abstract base class abstracting out some of the logical
  # flow of a `View` which shows query results.
  # 
  # `ResultsView`s must be passed `@options.context` and can be passed
  # `@options.initial_results`.  They Set up a `@results` collection and a 
  # `@notifications` collection and bind to their `add` and `reset` events.
  # 
  # If `@options.initial_results` is provided, its used to populates `@results`
  # otherwise the view performs a `$.ajax` query.  Once populated, and after
  # a restore, the view opens a live connection to subscribes to notifications.
  class ResultsView extends mobone.view.Widget
    
    # `query_url` API query endpoint.
    query_url: '/api/query'
    
    # Is this a view where it makes sense to bind to infinite scroll?
    should_bind_to_infinite_scroll: false
    
    # Has the view been snapshotted?
    restoring_from_snapshot: false
    
    # Subclasses should override `handleAddResult()`, `handleResetResults()` and 
    # `handleAddNotification()` and `handleResetNotifications()`.
    handleResetNotifications: (notifications) => # noop
    handleAddNotification: (notification) => # noop
    handleResetResults: (results) => # noop
    handleAddResult: (result) => # noop
    
    # `handleQuerySuccess()` resets `@notifications` and re-subscribes to
    # live updates.
    handleQuerySuccess: (data) =>
      @notifications.reset()
      @unsubscribe()
      @subscribe()
      
    
    handleQueryError: =>
      console.log 'XXX handle query error'
      
    
    
    # `snapshot()` unsubscribes from live updates and stops binding to scroll.
    snapshot: =>
      @unsubscribe()
      @unbindFromInfiniteScroll()
      
    
    # `restore()` subscribes to live updates and binds to scroll.
    restore: =>
      @subscribe()
      @bindToinfiniteScroll()
      
    
    
    # When the user scrolls to the end of the listing, go get more results.
    bindToInfiniteScroll: =>
      #if @should_bind_to_infinite_scroll
      # on scroll: 
      #   data = _.extend @query.toJSON(), until: @results.getTail()
      #   @performQuery data
      # 
      
    
    # Stop handling scroll.
    unbindFromInfiniteScroll: => # if @should_bind_to_infinite_scroll XXX
    
    # Subscribe to live updates, appending to `@notifications`.
    subscribe: =>
      query = @generateQuery()
      @subscription_id = $.sha1 JSON.stringify query
      liveClient.subscribe
        subscription_id: @subscription_id
        query: query
        since: @results.getHead()
        callback: (data) =>
          if data.subscription_id is @subscription_id
            # `data.results` should be a list `"#{type}:#{id}"` strings.
            to_add = []
            for item in data.results
              parts = item.split ':'
              model = new Backbone.Model
                type: parts[0]
                id: parts[1]
              to_add.push model
            @notifications.add to_add
          
        
      
    
    # Unsubscribe from live updates.
    unsubscribe: =>
      liveClient.unsubscribe @subscription_id if @subscription_id?
      
    
    
    # If we have any `@initial_results`, use them to populate `@results`,
    # otherwise populate `@results` by performing a query.
    populate: =>
      if @initial_results?
        @results.reset @initial_results
        delete @initial_results
        @handleQuerySuccess()
      else
        @performQuery @generateQuery()
      
    
    
    # Make a `$.ajax` request to the query API.
    performQuery: (data) =>
      $.ajax
        url: @query_url
        data: data
        dataType: 'json'
        error: @handleQueryError
        success: (data) =>
          @results.reset data.results
          @handleQuerySuccess data
        
      
    
    
    # Subclasses must override `generateQuery()` with a method that builds
    # a `togethr.model.Query`.
    generateQuery: =>
      throw "`ResultsView` implementations must override `generateQuery()`"
      
    
    
    # Store `@context` and any `@initial_results`, set up `@results` and 
    # `@notifications` and bind to events.
    initialize: ->
      # Store `@context` and any `@initial_results`.
      @context = @options.context
      @initial_results = @options.initial_results
      # Set up a `@results` and bind to `add` and `reset` events.
      @results = new togethr.model.ResultCollection
      @results.bind 'add', @handleAddResult
      @results.bind 'reset', @handleResetResults
      # Set up a `@notifications` and bind to `add` events.
      @notifications = new Backbone.Collection
      @notifications.bind 'add', @handleAddNotification
      @notifications.bind 'reset', @handleResetNotifications
      # Subscribe to notifications after populating `@results`
      @populate()
      # Bind to inifinite scroll.
      @bindToInfiniteScroll()
      
    
    
  
  # `ActivityStream` is a `ResultsView` showing a stream of action messages.
  class ActivityStream extends ResultsView
    
    # When `@results` is reset, clear the previous messages, render a `MessageEntry`
    # for each result and trigger a `messages:added` event.
    handleResetResults: =>
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
      
    
    # When a `message` is added to `@results`, render a `MessageEntry` and trigger
    # a `messages:added` event.
    handleAddResult: (message) =>
      # Prepend a `MessageEntry` to the stream.
      entry = new MessageEntry model: message
      @el.prepend entry.el
      # Notify that the message was added.
      $(document).trigger 'messages:added', models: [message]
      
    
    # Use `super` to reset `@notifications` and re-subscribe to live updates and
    # then update `@distance` if the server returned a different value (triggering
    # the `LocationBar` slider to reposition).
    handleSuccess: (data) =>
      # Reset `@notifications` and re-subscribe to live updates.
      super
      # If the distance has changed (bc the backend took over and found the
      # optimum range) ...
      distance = @distance.get 'value'
      if distance isnt data.distance
        # ... update the distance, using a flag to avoid triggering a new 
        # distance query.
        @ignore_set_distance = true
        @distance.set 'value': data.distance
      
    
    
    # `generateQuery()` from `@query`, `@locations.selected` and `@distance`.
    generateQuery: => 
      data = @query.toJSON()
      location = @locations.selected
      data.ll = "#{location.get 'latitude'},#{location.get 'longitude'}"
      if @include_distance
        data.distance = @distance.get 'value' if include_distance?
        @include_distance = false
      data
      
    
    
    # When `@context.get 'query'` changes perform a query.
    handleQueryChange: => 
      @performQuery @generateQuery()
      
    
    # When `@context.get 'distance'` changes, as long as we didn't trigger it,
    # perform a query with distance included.
    handleDistanceChange: =>
      if @ignore_set_distance
        @ignore_set_distance = false
      else
        @include_distance = true
        @performQuery @generateQuery()
        
      
    
    
    # If we have any `@initial_results`, use them to populate `@results`,
    # otherwise do nothing.
    populate: =>
      if @initial_results?
        @results.reset @initial_results
        delete @initial_results
        @handleQuerySuccess()
      
    
    
    snapshot: =>
      super
      @query.unbind 'change', @handleQueryChange
      @distance.unbind 'change', @handleDistanceChange
      @locations.unbind 'selection:changed', @handleQueryChange
      @previous_query = @query
      @previous_distance = @distance
      @previous_location = @locations.selected
      
    
    restore: =>
      @query.bind 'change', @handleQueryChange
      @distance.bind 'change', @handleDistanceChange
      @locations.bind 'selection:changed', @handleQueryChange
      if not _.isEqual @query, @previous_query
        @handleQueryChange()
      else if not _.isEqual @locations.selected, @previous_location
        @handleQueryChange()
      else if not _.isEqual @distance, @previous_distance
        @handleDistanceChange()
      else
        super
      
    
    
    initialize: ->
      @context = @options.context
      @query = @context.get 'query'
      @distance = @context.get 'distance'
      @locations = @context.get 'locations'
      @query.bind 'change', @handleQueryChange
      @distance.bind 'change', @handleDistanceChange
      @locations.bind 'selection:changed', @handleQueryChange
      super
      
    
  
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
  
  


