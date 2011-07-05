### Views i) update the UI ii) register and handle events.
###
$.namespace 'view', (exports) ->
  
  ### ``view.ContextView``
  ###
  exports.ContextView = Backbone.View.extend
    el: $ '#context-view'
    events:
      'keyup search-input': 'keyup'
    templates:
      titleBar: _.template """
          <div class="button navigation back">
            <a href="history.go(-1)"></a>
          </div>
          <div class="title">
            <%= title %>
          </div>
          <% _.each(buttons, function(item) { %>
            <div class="button navigation <%= item %>">
              <a href="#<%= name %>"></a>
            </div>
          <% }); %>
        """
      
    initialize: ->
      _.bindAll this, 'render', 'changeLocation'
      this.context.bind 'change', this.render
      this.messages.bind 'add', this.addMessage
      
    
    render: ->
      this.
      if not new_context.matches current_context
        current_context.kill()
        context.set new_context.toJSON
      if not current context:
        kill current context
        clear current context -> triggers content view render
        if location is not +here
          update location -> triggers location view highlight
      scroll to top
      show context view
    ##
      
      target = this.$ '.title-bar'
      title = model.escape 'title'
      if title
        target.html this.templates.titleBar
          title: title
          buttons: ['addBookmark']
        target.show()
      else
        target.html ''
        target.hide()
      return this
    
    keyup: ->
      # live search stuff
      
    
    
  
  
  
  
  
  
  
  
  

