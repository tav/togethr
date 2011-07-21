### ...
###
namespace 'message', (exports) ->
  
  templates = 
    messageEntry: string.template """
        <div class="user-profile-image left">
          <img src="build/gfx/user.png" />
        </div>
        <%~ content %>
        <div class="clear">
        </div>
      """
    messagePageElement: string.template """
          <div id="message/<%= id %>" class="page" data-role="page" data-theme="c">
          </div>
      """
    messagePageContent: string.template """
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
    
  
  class Message extends Backbone.Model
    
    localStorage: new Store 'messages'
    
  class MessageEntry extends Backbone.View
    
    className: 'message-entry'
    
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
      $(@el).html templates.messageEntry context
      
    
    
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
  
  

