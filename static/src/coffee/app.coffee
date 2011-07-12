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
      @pages[page_name] = @create page_name if not @pages[page_name]?
      @pages[page_name]
      
    
    # show the specified page
    show: (page_name, page_type) ->
      next_page = @pages[page_name]
      previous_page = @current_page
      # don't hide / show current page
      return if _.isEqual next_page, previous_page
      # update @current_page
      @current_page = next_page
      # if there's a current page sleep and hide it
      if previous_page?
        previous_page.snapshot()
        previous_page.hide()
      # wake and show the new page
      next_page.restore()
      next_page.show()
      # hide or show the footer as appropriate
      if page_type is 'dialog' then @footer.hide() else @footer.show()
      
    
    
    #
    handleHome: =>
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
    # if necessary fix the page footer / menu bar positioning, scrolling 1px
    # down to hide the address bar whilst we're at it
    $.support.fixedPosition (ok) -> 
        if not ok
          footer = new fix.FixedFooter el: $ '.foot'
      , 1
      
    
    # initialise the controller and provide ``app.navigate``
    controller = new Controller
    exports.navigate = controller.navigate
    # start handling requests and intercepting events
    interceptor = new util.Interceptor
    Backbone.history.start pushState: true
    
  
  
  exports.main = main
  


# provide ``app.main`` as ``window.togethr.main``
window.togethr ?= {}
window.togethr.main = app.main

