### ...
###
namespace 'message', (exports) ->
  
  templates = 
    messageEntry: _.template """
        <a href="/message/<%= id %>">
          <%= content %>
        </a>
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
        <br />la
      """
    messagePage: _.template """
        <div>
          XXX
          <br />
          <%= id %>
          <br />
          <%= content %>
        </div>
      """
    
  
  class Message extends Backbone.Model
    
    localStorage: new Store 'messages'
    
  class MessageEntry extends Backbone.View
    
    className: 'message-entry'
    
    initialize: ->
      @model.bind 'change', @render
      @render()
    
    render: =>
      context =
        id: @model.id
        content: @model.get 'content'
      $(@el).html templates.messageEntry context
      
    
    
  
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
    
    className: 'message-page'
    
    initialize: ->
      @model.bind 'change', @render
      @render()
      
    
    
    render: =>
      context =
        id: @model.id
        content: @model.get 'content'
      $(@el).html templates.messagePage context
      
    
    
  exports.Message = Message
  exports.Messages = Messages
  exports.MessageEntry = MessageEntry
  exports.MessagePage = MessagePage
  
  

