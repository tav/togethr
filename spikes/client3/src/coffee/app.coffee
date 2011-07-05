### ...
###
namespace 'app', (exports) ->
  
  ### ...
  ###
  Controller = Backbone.Router.extend
    
    ### Mapping of routes to controller methods.
    ###
    routes:
      ''                            : 'home'
      'space'                       : 'space'
      'challenge/:challenge'        : 'challenge'
      'message/:id'                 : 'message'
      'dialog/location'             : 'location'
      'dialog/jumpto'               : 'jumpto'
      ':user/:badge'                : 'badge'
      ':user'                       : 'user'
      
    
    ### Create the specified view.
    ###
    _create: (view_name) ->
      switch view_name
        when 'query_page'
          @query_page = new query.QueryPage
            el: $ '#query-page'
            query: @query
            location: @location
            messages: @messages
        # when ...
      
    
    ### If the specified view doesn't exist, create it.
    ###
    _ensure: (view_name) ->
      @[view_name] = @_create view_name if not @[view_name]?
      
    
    
    ### ...
    ###
    home: ->
      @_ensure 'query_page'
      # reset query
      # reset location
      query_page.scrollToTop()
      @_show 'query_page'
      
    
    ### ...
    ### 
    space: ->
      # q = $.parseQuery().q ? 'XXX'
      # @query.set 'value': q
      # console.log 'set q to ', q
      
    
    ### ...
    ###
    message: ->
      # ...
      
    
    ### ...
    ###
    location: ->
      # ...
      
    
    
  
  controller = Controller
  
  ### Main application entrypoint
  ###
  main = (data) ->
    ###
      
      * require geolocation to be switched on to use the app
      * then we know here
      * and we always have an initial location
      
      @user = new user.User data.user ? {}
      @query = new query.Query data.query ? {}
      @location = new loc.Location data.location ? bbox: ['1', '2', '3', '4'] # XXX
      
      controller.messages = new message.MessagesCollection
      
      Backbone.history.start pushState: true
      
    ###
    
  
  
  exports.navigate = controller.navigate
  exports.main = main
  


### Provide ``app.main`` as ``window.main`` in the browser (or 
  ``exports.main`` in commonJS).
###
root = exports ? window
root.togethr ?= {}
root.togethr.main = app.main

