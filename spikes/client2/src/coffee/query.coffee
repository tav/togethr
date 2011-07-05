$.namespace 'query', (exports) ->
  
  templates = 
    titleBar: _.template """
        <div data-role="toolbar" data-position="inline">
          <a href="#" data-rel="back"></a>
          <h1><%= title %></h1>
        </div>
      """
    
  
  class Query extends Backbone.Model
  
  class QueryPage extends Backbone.View
    
    ### Setup the page elements.
    ###
    initialize: ->
      _.bindAll this, 'render'
      @query = @options.query
      @location = @options.location
      @query.bind 'change', @render
      @location.bind 'change', @render
      @locationView = new loc.LocationView
        el: $ '#location-button'
        model: @location
      # search
      # menu bar
      # etc.
    
    ### Update the query view.
    ###
    render: ->
      if @location.has('bbox')
        # XXX ping the api to get messages
        messages = [
            id: 'msg-1'
            content: 'message 1'
          , 
            id: 'msg-2'
            content: 'message 2'
        ]
        # update the title bar
        queryValue = @query.get 'value'
        titleBar = @$ '.title-bar'
        if queryValue
          titleBar.html templates.titleBar title: queryValue
          titleBar.trigger 'enhance'
          titleBar.show()
        else
          titleBar.hide()
        # update the main window
        # XXX
        mainWindow = @$ '.main-window'
        mainWindow.html ''
        for item in messages
          m = new message.Message item
          v = new message.MessageEntry model: m
          mainWindow.append v.el
          mainWindow.trigger 'enhance'
        # XXX scroll to the appropriate point
      else
        console.log 'missing query or location'
      
    
  
  exports.Query = Query
  exports.QueryPage = QueryPage
  

