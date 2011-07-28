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
  
  # `ContextPage` is a base class abstracting out:
  # 
  # * accepting a context which may or may not have an initial result set in it
  # * selecting a default `ResultsView` when the context is first set / changes
  # * passing the context through to the selected `ResultsView`
  # 
  # `ContextPage` follows the same ensure / create / show algorithm to lazy-create
  # results views that the the `togethr.app.Controller` uses for page views.
  class ContextPage extends mobone.view.Page
    
    # Subclasses must provide the name of the `default_results_view`, e.g.: 'map'.
    default_results_view: null
    
    # `results_views` and `current_results_view` cache lazy-created results views.
    results_views: {}
    current_results_view: null
    
    # `createResultsView` creates and returns the specified results view, passing
    # `@context` through to it.
    createResultsView: (name) ->
      console.log "createResultsView #{name}"
      # By convention, `view_name` creates a `togethr.widget.ViewName`.
      view_class_name = ''
      for item in name.split '_'
        view_class_name += item.toTitleCase()
      ViewClass = togethr.widget[view_class_name]
      # All results views are given the same container as `@el`.
      @results_views[name] = new ViewClass
        el: @$ '.selectable-view-container'
        context: @context
      @results_views[name]
      
    
    
    # `createResultsView` shows the specified results view and updates it with
    # the latest `@context`.
    selectResultsView: (name) =>
      # Snapshot and hide any current results view.
      if @current_results_view?
        prev = @current_results_view
        prev.snapshot()
        prev.hide()
      # If the results view exists, wake it and update the context.
      if @results_views[name]?
        next = @results_views[name]
        next.restore()
        next.show()
      # Otherwise create it (which implicitly wakes it and passes in the context).
      else
        next = @createResultsView name
      # Store the current results view.
      @current_results_view = next
      
    
    
    # `refresh` re`render()`s and switches to the `@default_results_view`.
    refresh: =>
      @render()
      @selectResultsView @default_results_view
      
    
    
  
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
      # XXX we don't actually want: `@context.query.bind 'change', @refresh` here
      # (but we will for messages and other contexts).
      @refresh()
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
      
    
    
  
  # `MessagePage` is the main message page with `ReplyStream` results view.
  class MessagePage extends ContextPage
    default_results_view: 'reply_stream'
    
    templates:
      user: mobone.string.templateFromId 'message-page-user-template'
      content: mobone.string.templateFromId 'message-page-content-template'
    
    handleSwipeRight: (event) =>
      # If the event was triggered from within the results stream, ignore it.
      target = $ event.target
      return true if target.closest('selectable-view-container').length > 0
      # Otherwise go back.
      history.back()
      false
      
    
    
    render: ->
      console.log 'MessagePage.render', @
      message = @messages.selected
      if message?
        data = message.toJSON()
        @$('.message-user').html @templates.user data
        @$('.message-content').html @templates.content data
      
    
    
    # Set `@context`, bind to `selection:changed` events, bind to `swiperight`
    # events, make the header buttons relative and `refresh()`.
    initialize: ->
      @context = new Backbone.Model messages: @options.messages
      @messages = @options.messages
      @messages.bind 'selection:changed': @refresh
      @el.bind 'swiperight', @handleSwipeRight
      #new mobone.view.RelativeButton el: item for item in @$ '[data-relative-path]'
      @refresh()
      
    
    
  
  exports.QueryPage = QueryPage
  exports.MessagePage = MessagePage
  


