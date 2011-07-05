$.namespace 'message', (exports) ->
  
  templates = 
    messageEntry: _.template """
        <a href="#messages/<%= id %>">
          <%= content %>
        </a>
      """
    messagePage: _.template """
        <div data-role="page" id="message/<%= id %>" data-add-back-btn="true">
          <div data-role="header" data-position="inline">
            <h1>Message</h1>
          </div>
          <div data-role="content">  
            <p>Message</p>
            <p>
              <%= content %>
            </p>
          </div>
          <div data-role="footer">
            <h4>Page Footer</h4>
          </div>
        </div>
      """
    
  
  class Message extends Backbone.Model
  
  class MessageEntry extends Backbone.View
    
    className: 'message-entry'
    
    events:
      'click a': 'createPage'
    
    initialize: ->
      _.bindAll this, 'render', 'createPage'
      @model.bind 'change', @render
      @render()
    
    render: ->
      $(@el).html templates.messageEntry
        id: @model.id
        content: @model.get 'content'
      
    
    createPage: ->
      messagePage = new MessagePage model: @model
      page = messagePage.$('div').first()
      page.appendTo($.mobile.pageContainer).page()
      page.jqmData 'url', "#{page.attr 'id'}"
      $.mobile.changePage page
      false
      
    
  
  class MessagePage extends Backbone.View
    
    className: 'message-page'
    
    initialize: ->
      _.bindAll this, 'render'
      @model.bind 'change', @render
      @render()
      
    
    
    render: ->
      $(@el).html templates.messagePage
        id: @model.id
        content: @model.get 'content'
      
    
    
  
  exports.Message = Message
  exports.MessageEntry = MessageEntry
  exports.MessagePage = MessagePage
  
  

