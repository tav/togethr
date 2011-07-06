### ...
###
namespace 'app', (exports) ->
  
  ### ...
  ###
  class Controller extends Backbone.Router
    
    ### Mapping of routes to controller methods.
    ###
    routes:
      ''                            : 'handleHome'
      'space'                       : 'handleSpace'
      'challenge/:challenge'        : 'handleChallenge'
      'message/:id'                 : 'handleMessage'
      'dialog/location'             : 'handleSetLocation'
      'dialog/jumpto'               : 'handleJumpTo'
      ':user/:badge'                : 'handleBadge'
      ':user'                       : 'handleUser'
      
    
    ### Create the specified page.
    ###
    _create: (page_name) ->
      switch page_name
        when 'query'
          @_pages.query = new query.QueryPage
            el: $ '#query-page'
            user: @user
            query: @query
            messages: @messages
            location: @location
          
        # when ...
      
    
    ### If the specified page doesn't exist, create it.
    ###
    _ensure: (page_name) ->
      @_pages[page_name] = @_create page_name if not @_pages[page_name]?
      
    
    ### Show the specified page.
    ###
    _show: (page_name) ->
      # XXX do this properly
      for own k, v in @_pages
        target = $ v.el
        if k is page_name
          target.show()
        else 
          target.hide()
        
      
    
    
    ### ...
    ###
    handleHome: =>
      console.log 'handling home'
      @_ensure 'query'
      @query.set 'value': ''
      @location.set @here.toJSON()
      @_show 'query_page'
      
    
    ### ...
    ### 
    handleSpace: =>
      console.log 'handling space'
      @_ensure 'query'
      @query.set 'value', $.parseQuery().q ? ''
      @_show 'query_page'
      
    
    ### ...
    ###
    handleMessage: =>
      console.log 'handling message'
      
    
    ### ...
    ###
    handleSetLocation: =>
      console.log 'handling location'
      
    
    ### ...
    ###
    handleUser: =>
      console.log 'handling user'
      
    
    
    ### ...
    ###
    initialize: (options, @user, @query, @messages, @here, @location) ->
      @_pages = new Object
      
    
    
  
  ### Main application entrypoint
  ###
  main = (data) ->
    
    # set ``current_user`` to ``data.user`` or default to a guest
    current_user = new user.User data.user ? {}
    
    # set ``current_query`` to ``data.query`` or default to no filters
    current_query = new query.Query data.query ? {}
    
    # if given ``data.messages`` populate the ``messages`` collection
    messages = new message.MessageCollection
    if data.messages?
      items = (new message.Message item for item in data.messages)
      messages.add items
    
    # get the user's location upfront (this simplifies things enormously)
    # XXX HACK for testing
    $.geolocation.find = (cb) -> cb {latitude: 51.5197, longitude: -0.1408}
    # XXX END HACK
    $.geolocation.find (coords) ->
        
        # set ``here`` to the user's location
        here = location.Location.createFromCoords coords, 'here'
        
        # if given ``data.location``, set ``current_location`` to it
        if data.location?
          current_location = new location.Location data.location
        else # default ``current_location`` to ``here``
          current_location = here.clone()
        
        # initialise the controller and start handling requests
        controller = new Controller null, current_user, current_query, \
                                    messages, here, current_location
        
        # provide ``app.navigate``
        exports.navigate = controller.navigate
        
        # start handling requests
        Backbone.history.start pushState: true
        
      , ->
        
        # XXX show a proper user interface here
        alert 'togethr needs to know your location'
        window.location.reload()
      
    
  
  exports.main = main
  


### Provide ``app.main`` as ``window.togethr.main``.
###
window.togethr ?= {}
window.togethr.main = app.main

