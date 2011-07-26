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
      
    
    
  
  exports.QueryPage = QueryPage
  
  
  class MessagePage extends mobone.view.Page
    
    @elementTemplate: mobone.string.template """
        <div id="message/<%= id %>" class="page" data-role="page" data-theme="c">
        </div>
      """
    
    pageContentTemplate: mobone.string.template """
        <div class="head" data-role="header">
          <a href="/"
              data-role="button" 
              data-inline="true" 
              data-rel="back"
              data-icon="back"
              data-iconpos="notext" 
              class="left">Back</a>
          <div class="right .ui-btn-right" data-inline="true">
            <a href="/message/<%= id %>/appreciate" data-role="button">
              Appreciate</a>
            <a href="/message/<%= id %>/jumpTo" data-role="button">
              Jump To</a>
          </div>
          <h1 class="title">Message</h1>
        </div>
        <div class="body" data-role="content">
          <div class="window main-window">
            <!-- user -->
            <div class="row message-row message-user">
              <a href="/<%= user.username %>" title="<%= user.username %>">
                <div class="user-profile-image left">
                  <img src="<%= user.profile_image %>" />
                </div>
                @<%= user.username %></a>
              <div class="clear">
              </div>
            </div>
            <!-- message -->
            <div class="row message-row message-content">
              <%~ content %>
            </div>
            <div class="row message-row message-comments">
              <ul class="comments-list">
                <% _.each(comments, function(comment) { %>
                  <li class="comment">
                    <div class="comment-user">
                      <a href="/<%= comment.user.username %>" title="<%= comment.user.username %>">
                        <div class="user-profile-image left">
                          <img src="<%= comment.user.profile_image %>" />
                        </div>
                        @<%= user.username %></a>:
                      <%~ comment.content %>
                      <div class="clear">
                      </div>
                    </div>
                  </li>
                <% }); %>
              </ul>
            </div>
            <!-- reply UI -->
          </div>
        </div>
      """
    
    # static method that returns a new element
    @generateElement: (msgid) ->
      $(@elementTemplate id: msgid)
      
    
    
    initialize: ->
      @model.bind 'change', @render
      context = @model.toJSON()
      console.log context
      @el.append $(@pageContentTemplate(context))
      @el.bind 'swiperight', @handleBack
      @el.page()
      @render()
      
    
    render: =>
      # XXX
      
    
    
    handleBack: =>
      history.back()
      false
    
    
  
  exports.MessagePage = MessagePage
  
  


