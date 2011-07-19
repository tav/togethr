### ...
###
namespace 'message', (exports) ->
  
  templates = 
    messageEntry: _.template """
          <div class="user left">
            <img src="build/gfx/user.png" />
          </div>
          <%= content %>
          <div class="clear">
          </div>
        </a>
      """
    messagePage: _.template """
        <div id="messages/<%= id %>" class="page" 
            data-role="page" 
            data-theme="c">
          <div data-role="header">
          </div>
          <div class="body" data-role="content">
            <div class="head">
              <div class="bar title-bar ui-header">
                <a href="/"
                    data-role="button" 
                    data-inline="true" 
                    data-rel="back"
                    data-icon="back"
                    data-iconpos="notext" 
                    class="left">Back</a>
                <div class="title ui-title"><%= id %></div>
              </div>
            </div>
            <div class="window main-window">
              <%= content %>
            </div>
          </div>
        </div>
      """
    
  
  class Message extends Backbone.Model
    
    localStorage: new Store 'messages'
    
  class MessageEntry extends Backbone.View
    
    className: 'message-entry'
    
    events:
      'tap'               : 'showMessage'
      'swipeleft'         : 'showMessage'
    
    
    initialize: ->
      @model.bind 'change', @render
      @render()
    
    render: =>
      context =
        id: @model.id
        content: @model.get 'content'
      $(@el).html templates.messageEntry context
      
    
    showMessage: (event) =>
      console.log 'MessageEntry.showMessage'
      console.log event.type
      url = "/message/#{@model.id}"
      app.navigate url, true
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
    
    initialize: ->
      @model.bind 'change', @render
      context =
        id: @model.id
        content: @model.get 'content'
      @el = $ templates.messagePage(context)
      $('.page-container').append(@el)
      @el.page()
      @render()
      
    
    render: =>
      # XXX
      
    
    
  
  exports.Message = Message
  exports.Messages = Messages
  exports.MessageEntry = MessageEntry
  exports.MessagePage = MessagePage
  
  

