### ...
###
namespace 'app', (exports) ->
  
  ### ``Controller`` sets up the application and handles internal requests.
  ###
  class Controller extends Backbone.Router
    
    # mapping of routes to handlers
    routes:
      ''                            : 'handleHome'
      '/'                           : 'handleHome'
      '/query?q=:value'             : 'handleQuery'
      '/message/:msgid'             : 'handleMessage'
      '/challenge/:challenge'       : 'handleChallenge'
      '/dialog/location'            : 'handleLocation'
      '/dialog/jumpto'              : 'handleJumpTo'
      '/:user/:badge'               : 'handleBadge'
      '/:user'                      : 'handleUser'
      '/*'                          : 'handle404'
      
    
    # cached page views
    pages: {}
    current_page: null
    
    # create the specified page
    create: (page_name) ->
      console.log "create #{page_name}"
      switch page_name
        when 'query'
          @pages.query = new query.QueryPage
            el: $ '#query-page'
            query: @query
            locations: @locations
        when 'location'
          @pages.location = new location.LocationDialog
            el: $ '#location-dialog'
            locations: @locations
          
        
      
    
    # make sure the specified page exists (and return it)
    ensure: (page_name) ->
      console.log "ensure #{page_name}"
      @create page_name if not @pages[page_name]?
      @pages[page_name]
      
    
    # show the specified page
    show: (page_name, page_type) ->
      # use the jquery mobile machinery to change to the specified page
      url = "##{@pages[page_name].el.jqmData 'url'}"
      $.mobile.changePage url,
        changeHash: false
        fromHashChange: true
      # hide or show our special case footer as appropriate
      if page_type is 'dialog' then @footer.hide() else @footer.show()
      
    
    
    #
    handleHome: =>
      #@handleLocation()
      console.log 'handling home'
      @ensure 'query'
      @query.set value: ''
      @show 'query', 'page'
      
    
    # 
    handleQuery: (value) =>
      console.log 'handling query', value
      @ensure 'query'
      @query.set 'value': value
      @show 'query', 'page'
      
    
    #
    handleMessage: (msgid) =>
      console.log 'handling message', msgid
      
    
    #
    handleLocation: =>
      console.log 'handling location'
      @ensure 'location'
      @show 'location', 'dialog'
      
    
    #
    handleUser: =>
      console.log 'handling user'
      
    
    #
    handle404: =>
      alert 'This was not the page you were looking for.'
      window.history.go(-1)
      
    
    
    # 
    initialize: (@here) ->
      # create and populate a ``@locations`` collection
      @locations = new location.Locations [@here]
      @locations.fetch add: true
      # create and populate a ``@bookmarks`` collection
      @bookmarks = new bookmark.Bookmarks
      @bookmarks.fetch()
      # create and sync a ``@user`` instance
      @user = new user.User
      @user.fetch()
      # create an ``@query`` instance
      @query = new query.Query
      # setup application wide ``View`` components
      @footer = new footer.FooterWidget el: $ '#footer-wrapper'
      # ...
      
    
  
  # init once we know we have ``here`` (the current location)
  init = (here) ->
    
    # initialise the controller and provide ``app.navigate``
    controller = new Controller here
    exports.navigate = controller.navigate
    
    # start handling requests and intercepting events
    interceptor = new util.Interceptor
    Backbone.history.start pushState: true
    
  
  
  _start = (here) ->
    here.start (ok) =>
      if ok
        init here
      else
        alert 'Togethr.at needs to know your location.'
        window.location.reload()
      
    
  
  
  # main application entrypoint
  main = ->
    # create a ``Here`` instance
    here = new location.Here id: '+here'
    # see if we have +here in local storage
    here.fetch
      error: -> 
        _start here
      success: ->
        if here.isRecent()
          here.startWatching true
          init here
        else 
          _start here
    # if necessary fix the page footer / menu bar positioning
    $.support.fixedPosition (ok) -> 
        if not ok
          footer = new fix.FixedFooter el: $ '.foot'
      , 1
    
    
  
  
  exports.main = main
  


# provide ``app.main`` as ``window.togethr.main``
window.togethr ?= {}
window.togethr.main = app.main

