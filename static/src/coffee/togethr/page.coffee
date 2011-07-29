# `togethr.page` provides `Backbone.View` classes that render and apply dynamic
# behaviour to dynamic pages that are instantiated once, provide a fixed user
# interface and re-render as the context changes:
# 
# * `QueryPage`
# * `MessagePage`
# 
# Plus soon add to that:
# 
# * `SpacePage`
# * `UserPage`
# * `BadgePage`
mobone.namespace 'togethr.page', (exports) ->
  
  # `ContextPage` is a base class abstracting out some of the logical flow of
  # a `Page` which represents a particular context (like a @user or a #hashtag).
  # 
  # It provides methods to:
  # 
  # * `reset()` which renders and creates a new default `ResultView`
  # * `update()` which renders and creates a new current `ResultView`
  # * `select()` which creates a new selected `ResultView`
  # 
  # These methods all require subclasses to provide `@context` (and optionally
  # also look for `@initial_results`), which they pass through to the `ResultView`
  # when creating it.
  class ContextPage extends mobone.view.Page
    
    # Subclasses must provide a default results view name, e.g.: 'activity_stream'.
    # By convention, `results_view_name` creates a `togethr.widget.ResultsViewName`.
    default_results_view_name: null
    
    current_results_view_name: null
    current_results_view: null
    
    # `_create(results_view)` creates and returns the specified results view,
    # passing `@context` through to it.
    _create: (results_view_name) =>
      # Require `@context` and `results_view_name`.
      throw "`ContextPage`s must provide `@context`." if not @context?
      throw "`results_view_name` is required." if not results_view_name?
      # By convention, `results_view_name` creates a `togethr.widget.ResultsViewName`.
      class_name = ''
      class_name += item.toTitleCase() for item in results_view_name.split '_'
      ResultsView = togethr.widget[class_name]
      # Kill the `current_results_view`.
      if @current_results_view?
        @current_results_view.snapshot()
        @current_results_view.el.html ''
        delete @current_results_view
      # Store the results view name and return the results view.
      @current_results_view_name = results_view_name
      @current_results_view = new ResultsView
        el: @$ '.selectable-view-container'
        context: @context
        initial_results: @initial_results
      # Make sure it's a `ResultsView`
      if @current_results_view not instanceof togethr.widget.ResultsView
        throw "#{ResultsView} is not a `ResultsView`" 
      
    
    
    # `render()` does nothing by default.
    render: => # noop
    
    # `reset()` renders and creates a new default results view.
    reset: =>
      @render()
      @_create @default_results_view
      
    
    # `update()` renders and creates a new current result view.
    update: =>
      @render()
      @_create @current_results_view_name ? @default_results_view
      
    
    # `select()` creates a new selected `ResultView`.
    select: (results_view_name) =>
      @_create results_view_name ? @default_results_view
      
    
    
    # Tell the current results view to snapshot and restore when the page does.
    snapshot: => @current_results_view.snapshot() if @current_results_view?
    restore: => @current_results_view.restore() if @current_results_view?
    
    # Bind to `.results-view-select` `change` events.
    initialize: ->
      target = @$ '.results-view-select'
      target.val @default_results_view_name
      target.selectmenu 'refresh', true
      target.bind 'change', => @select target.val()
      
    
    
  
  # `QueryPage` is the main search / results page.
  class QueryPage extends ContextPage
    widgets: {}
    default_results_view: 'activity_stream'
    
    initialize: ->
      # Set `@context`, bind to `@context` `change` events, and `refresh()`.
      @context = new Backbone.Model
        query: @options.query
        distance: @options.distance
        locations: @options.locations
      @reset()
      # XXX Setup select view widget.
      # ... `selectResultsView view_name` ...
      # Setup the top, search and location bars.
      @widgets.togethr_bar = new togethr.widget.TogethrBar
        el: @$ '.togethr-bar'
        collection: @options.locations
      @widgets.search_bar = new togethr.widget.SearchBar
        el: @$ '.search-bar'
      @widgets.location_bar = new togethr.widget.LocationBar
        el: @$ '.location-bar'
        model: @options.distance
      super
    
    
  
  # `MessagePage` is the main message page with `ReplyStream` results view.
  class MessagePage extends ContextPage
    default_results_view: 'reply_stream'
    
    templates:
      user: mobone.string.templateFromId 'message-page-user-template'
      content: mobone.string.templateFromId 'message-page-content-template'
    
    # If the event was triggered from within the results stream, ignore it.
    # Otherwise go back.
    handleSwipeRight: (event) =>
      return if $(event.target).closest('selectable-view-container').length > 0
      history.back()
      false
      
    
    # Update the user and message content.
    render: ->
      message = @messages.selected
      data = message.toJSON()
      @$('.message-user').html @templates.user data
      @$('.message-content').html @templates.content data
      
    
    # Set `@context`, bind to `selection:changed` events, bind to `swiperight`
    # events and make the header buttons relative.
    initialize: ->
      @context = new Backbone.Model messages: @options.messages
      @messages = @options.messages
      @messages.bind 'selection:changed', @reset
      @el.bind 'swiperight', @handleSwipeRight
      new mobone.view.RelativeButton el: item for item in @$ '[data-relative-path]'
      super
    
  
  exports.QueryPage = QueryPage
  exports.MessagePage = MessagePage
  


