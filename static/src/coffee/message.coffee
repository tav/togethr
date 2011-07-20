### ...
###
namespace 'message', (exports) ->
  
  templates = 
    messageEntry: _.template """
        <div class="user-profile-image left">
          <img src="build/gfx/user.png" />
        </div>
        <%= content %>
        <div class="clear">
        </div>
      """
    messagePageElement: _.template """
          <div id="message/<%= id %>" class="page" data-role="page" data-theme="c">
          </div>
      """
    messagePageContent: _.template """
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
                <%= content %>
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
                        <%= comment.content %>
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
    
  
  class Message extends Backbone.Model
    
    localStorage: new Store 'messages'
    
  class MessageEntry extends Backbone.View
    
    className: 'message-entry'
    
    initialize: ->
      @model.bind 'change', @render
      $(@el).bind 'tap click swipeleft', @showMessage
      @render()
    
    render: =>
      context =
        id: @model.id
        content: @model.get 'content'
      $(@el).html templates.messageEntry context
      
    
    showMessage: (event) =>
      url = "/message/#{@model.id}"
      app.navigate url, true
      event.stopImmediatePropagation()
      false
      
    
  
  class Messages extends Backbone.Collection
    
    model: Message
    localStorage: new Store 'messages'
    
    initialize: ->
      @bind 'add', @applyView
      @bind 'reset', => @each @applyView
      
    
    
    applyView: (message) =>
      entry = new MessageEntry model: message
      message.view = entry
      
    
    
  
  class MessagePage extends baseview.Page
    
    # static method that returns a new element
    @generateElement: (msgid) ->
      $(templates.messagePageElement id: msgid)
      
    
    
    initialize: ->
      @model.bind 'change', @render
      context = @model.toJSON()
      console.log context
      @el.append $(templates.messagePageContent(context))
      @el.bind 'swiperight', @handleBack
      @el.page()
      @render()
      
    
    render: =>
      # XXX
      
    
    
    handleBack: =>
      history.back()
      false
    
    
  
  exports.Message = Message
  exports.Messages = Messages
  exports.MessageEntry = MessageEntry
  exports.MessagePage = MessagePage
  
  

