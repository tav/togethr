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
      
    
    
    initialize: ->
      
      ###
        
        @here = new location.Here # cookie cached, ongoing geo tracking
        @here.fetch
          success: ->
            # the rest of the setup...
          
        
        
      ###
      
      # setup ``here`` and fetch any existing ``@locations``
      @here = new location.Here
      @locations = new location.Locations [@here]
      @locations.fetch add: true
      
      # setup and fetch any existing ``@bookmarks``
      @bookmarks = new bookmark.Bookmarks
      @bookmarks.fetch()
      
      # setup ``@user`` and fetch any details
      @user = new user.User
      @user.fetch()
      
      # setup ``@query``
      @query = new query.Query
      
      # setup application wide ``View`` components
      @footer = new footer.FooterWidget el: $ '#footer-wrapper'
      
    
    
  
  # main application entrypoint
  main = ->
    console.log 'main()'
    # initialise the controller and provide ``app.navigate``
    controller = new Controller
    exports.navigate = controller.navigate
    # start handling requests and intercepting events
    interceptor = new util.Interceptor
    Backbone.history.start pushState: true
    # if necessary fix the page footer / menu bar positioning, scrolling 1px
    # down (with a sledgehammer) to hide the address bar whilst we're at it
    window.scrollTo 0, 1
    $.support.fixedPosition (ok) -> 
        if not ok
          footer = new fix.FixedFooter el: $ '.foot'
          $(window).load -> $.mobile.silentScroll 0, 1
      , 1
    
    
  
  
  exports.main = main
  


# provide ``app.main`` as ``window.togethr.main``
window.togethr ?= {}
window.togethr.main = app.main

