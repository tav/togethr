### ...
###
namespace 'message', (exports) ->
  
  templates = 
    messageEntry: _.template """
        <a href="/message/<%= id %>">
          <%= content %>
        </a>
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
      
    
    
  
  class MessageCollection extends Backbone.Collection
    
    model: Message
    
    initialize: ->
      @bind 'add', (message) =>
        entry = new MessageEntry model: message
        message.view = entry
        
      
    
  
  class MessagePage extends Backbone.View
    
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
  exports.MessageCollection = MessageCollection
  exports.MessageEntry = MessageEntry
  exports.MessagePage = MessagePage
  
  

