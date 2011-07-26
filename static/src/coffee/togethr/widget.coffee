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
      target.text @locations.selected.get 'id'
      
    
    
  
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
    template: mobone.string.template """
        <div class="user-profile-image left">
          <img src="build/gfx/user.png" />
        </div>
        <%~ content %>
        <div class="clear">
        </div>
      """
    
    initialize: ->
      @model.bind 'change', @render
      @render()
      target = $(@el)
      target.bind 'vmousedown', @handleTouchStart
      target.bind 'vmouseup', @handleTouchEnd
      target.bind 'swipeleft', @showMessage
      target.bind 'swiperight', @showParent
      
    
    render: =>
      context =
        id: @model.id
        content: @model.get 'content'
      $(@el).html @template context
      
    
    
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
    
  
  exports.MessageEntry = MessageEntry
  
  
  # `ResultsView` is a base class for widgets that accept a contexts.
  class ResultsView extends mobone.view.Widget
    
    # Expect `@options.context`, set it to `@context`.
    initialize: -> 
      console.log 'new ResultsView', @options.context
      @context = @options.context
      @initial_results = @context.get 'initial_results'
      @context.unset 'initial_results'
      
    
    
  
  class ActivityStream extends ResultsView
    
    handleAdd: =>
      # @el.append message.view.el
      
    
    handleReset: =>
      # @el.html ''
      # @collection.each (message) => @el.append message.view.el
      
    
    
    handleResults: (data) =>
      console.log 'handleResults', data
      @results.reset data.results
      # if the distance has changed (bc the backend took over and found the
      # optimum range)
      distance = @context.get('distance')
      if not (distance.get 'value' is data.distance)
        # update the distance, which triggers @location_bar
        # using a flag to avoid triggering a distance query
        @ignore_set_distance = true
        distance.set 'value': data.distance
      
    
    fetchMessages: (query, location, distance, success, failure) =>
      data = query.toJSON()
      data.ll = "#{location.get 'latitude'},#{location.get 'longitude'}"
      data.distance = distance.get 'value' if distance?
      $.ajax
        url: '/api/messages'
        data: data
        dataType: 'json'
        success: success
        error: failure
      
    
    
    performQuery: =>
      console.log 'performQuery', @query
      query = @context.get('query')
      location = @context.get('locations').selected
      @fetchMessages query, location, null, @handleResults, -> alert 'XXX'
      
    
    performDistanceQuery: =>
      console.log 'performDistanceQuery', @context.query, @context.distance
      if @ignore_set_distance
        @ignore_set_distance = false
        return
      query = @context.get('query')
      distance = @context.get('distance')
      location = @context.get('locations').selected
      @fetchMessages query, location, distance, @handleResults, -> alert 'XXX'
      
    
    
    snapshot: =>
      @context.get('query').unbind 'change', @performQuery
      @context.get('distance').unbind 'change', @performDistanceQuery
      @previous_query = @context.get 'query'
      @previous_distance = @context.get 'distance'
      
    
    restore: =>
      @context.get('query').bind 'change', @performQuery
      @context.get('distance').bind 'change', @performDistanceQuery
      @initial_results = @context.get 'initial_results'
      @context.unset 'initial_results'
      @handleResults @initial_results if @initial_results?
      
    
    
    initialize: ->
      super
      @results = new Backbone.Collection model: togethr.model.Message
      @results.bind 'add', @handleAdd
      @results.bind 'reset', @handleReset
      @restore()
      
    
  
  exports.ResultsView = ResultsView
  exports.ActivityStream = ActivityStream
  
  
  class FooterWidget extends mobone.view.Widget
    act_path: 'app/select/action'
    events:
      'click .act-button': 'handleActButtonClick'
    
    initialize: ->
      bar = @$ '.menu-bar'
      bar.navbar()
      
    
    handleActButtonClick: (event) =>
      path = Backbone.history.getFragment()
      ends_with = path.charAt(path.length - 1)
      path = "#{path}/" if not (ends_with is '/')
      app.navigate "#{path}#{@act_path}", true
      false
      
    
    
  
  exports.FooterWidget = FooterWidget
  
  


