### ...
###
namespace 'app', (exports) ->
  
  ### ...
  ###
  class Controller extends Backbone.Router
    
    # mapping of routes to controller methods
    routes:
      ''                            : 'handleHome'
      '/'                           : 'handleHome'
      '/query?q=:value'             : 'handleQuery'
      '/message/:msgid'             : 'handleMessage'
      '/challenge/:challenge'       : 'handleChallenge'
      '/dialog/location'            : 'handleSetLocation'
      '/dialog/jumpto'              : 'handleJumpTo'
      '/:user/:badge'               : 'handleBadge'
      '/:user'                      : 'handleUser'
      '/*'                          : 'handle404'
      
    
    # cached page views
    pages: new Object
    current_page: null
    
    # create the specified page
    create: (page_name) ->
      switch page_name
        when 'query'
          @pages.query = new query.QueryPage
            el: $ '#query-page'
            user: @user
            query: @query
            messages: @messages
            location: @location
          
        # when ...
      
    
    # make sure the specified page exists
    ensure: (page_name) ->
      @pages[page_name] = @create page_name if not @pages[page_name]?
      
    
    # show the specified page
    show: (page_name) ->
      if current_page?
        current_page.sleep()
        current_page.hide()
      current_page = @pages[page_name]
      current_page.wake()
      current_page.show()
      
    
    
    ### ...
    ###
    handleHome: =>
      console.log 'handling home'
      @ensure 'query'
      @query.set 'value': ''
      @location.set @here.toJSON()
      @show 'query'
      
    
    ### ...
    ### 
    handleQuery: (value) =>
      console.log 'handling query', value
      @ensure 'query'
      @query.set 'value': value
      @show 'query'
      
    
    ### ...
    ###
    handleMessage: (msgid) =>
      console.log 'handling message', msgid
      
    
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
    handle404: =>
      alert 'This was not the page you were looking for.'
      window.history.go(-1)
      
    
    
    ### ...
    ###
    initialize: (@user, @query, @messages, @here, @location) ->
    
  
  
  ### Main application entrypoint
  ###
  main = (data) ->
    
    # bootstrap the client application state using the ``data`` provided
    current_user = new user.User data.user ? {}
    current_query = new query.Query data.query ? {}
    messages = new message.MessageCollection
    if data.messages?
      messages.add new message.Message item for item in data.messages
    
    # XXX HACK for testing
    $.geolocation.find = (cb) -> cb {latitude: 51.5197, longitude: -0.1408}
    # XXX END HACK
    
    # get the user's location
    $.geolocation.find (coords) ->
        
        # set ``here`` to the user's location
        here = location.Location.createFromCoords coords, 'here'
        # if given ``data.location``, set ``current_location`` to it
        if data.location?
          current_location = new location.Location data.location
        else # default ``current_location`` to ``here``
          current_location = here.clone()
        
        # initialise the controller
        controller = new Controller current_user, current_query, messages, here, current_location
        # start handling requests
        Backbone.history.start pushState: true
        # start intercepting vclick and submit events
        interceptor = new util.Interceptor
        
        # provide ``app.navigate``
        exports.navigate = controller.navigate
        
      , ->
        
        # XXX show a proper user interface
        alert 'togethr needs to know your location, please try again'
        window.location.reload()
      
      
    
    
    # if necessary fix the page footer / menu bar positioning, scrolling 1px
    # down to hide the address bar whilst we're at it
    $.support.fixedPosition (ok) -> 
        if not ok
          footer = new fix.FixedFooter el: $ '.foot'
      , 1
      
    
    
  
  
  exports.main = main
  


### Provide ``app.main`` as ``window.togethr.main``.
###
window.togethr ?= {}
window.togethr.main = app.main

