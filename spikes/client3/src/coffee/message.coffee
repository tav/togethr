### ...
###
namespace 'message', (exports) ->
  
  templates = 
    messageEntry: _.template """
        <a href="/messages/<%= id %>">
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
      _.bindAll this, 'render', 'createPage'
      @model.bind 'change', @render
      @render()
    
    render: ->
      context =
        id: @model.id
        content: @model.get 'content'
      $(@el).html templates.messageEntry context
      
    
    
  
  class MessagePage extends Backbone.View
    
    className: 'message-page'
    
    initialize: ->
      _.bindAll this, 'render'
      @model.bind 'change', @render
      @render()
      
    
    
    render: ->
      context =
        id: @model.id
        content: @model.get 'content'
      $(@el).html templates.messagePage context
      
    
    
  exports.Message = Message
  exports.MessageEntry = MessageEntry
  exports.MessagePage = MessagePage
  
  

