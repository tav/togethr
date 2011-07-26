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
  
  class QueryPage extends mobone.view.Page
    widgets: {}
    
    initialize: ->
      # Setup the top, search and location bars.
      @widgets.togethr_bar = new togethr.widget.TogethrBar
        el: @$ '.togethr-bar'
        collection: @model.locations
      @widgets.search_bar = new togethr.widget.SearchBar
        el: @$ '.search-bar'
      @widgets.location_bar = new togethr.widget.LocationBar
        el: @$ '.location-bar'
        model: @model.distance
        locations: @model.locations
      
      # XXX Setup the default view
      #@results_view = new togethr.widget.ActivityStream
      #  el: @$ '.main-window'
      #  model: @model
      #
      
    
    
  
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
  
  


