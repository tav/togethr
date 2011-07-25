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
namespace 'togethr.page', (exports) ->
  
  class QueryPage extends mobone.view.Page
    ignore_set_distance: false
    
    initialize: ->
      
      @query = @options.query
      @locations = @options.locations
      @messages = @options.messages
      @distance = @options.distance
      
      @search_bar = new togethr.widget.SearchBar
        el: @$ '.search-bar'
      
      @title_bar = new togethr.widget.TitleBar
        el: @$ '.title-bar'
        model: @query
      
      @location_bar = new togethr.widget.LocationBar
        el: @$ '.location-bar'
        model: @distance
        locations: @locations
      
      @results_view = new togethr.widget.ActivityStream
        el: @$ '.main-window'
        collection: @messages
      
      @query.bind 'change', @performQuery
      @locations.bind 'selection:changed', @performQuery
      @distance.bind 'change', @performDistanceQuery
      
    
    
    handleResults: (query_value, results, distance) =>
      # update the messages, which triggers @results_view to render
      items = (new togethr.model.Message item for item in results)
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
      results = []
      for i in [1..12]
        n = Math.random()
        comments = []
        for j in [1..8]
          comments.push
            content: "Comment #{Math.random()} lorum comment content ipsum dolores"
            user:
              username: 'username'
              profile_image: '/build/gfx/user.png'
        results.push
          id: "msg-#{n}"
          content: "Message #{n} #lorum ipsum #dolores dulcit!"
          hashtags: ['lorum', 'dulcit']
          comments: comments
          user:
            username: 'username'
            profile_image: '/build/gfx/user.png'
      r = Math.random()
      distance = distance ? Math.sqrt(r * r * r * 100000)
      success query_value, results, distance
      
    
    
    performQuery: =>
      console.log 'performQuery', @locations, @query
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
  
  


