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
      # XXX do this properly
      for own k, v in @pages
        target = $ v.el
        if k is page_name
          target.show()
        else 
          target.hide()
        
      
    
    
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
    initialize: (options, @user, @query, @messages, @here, @location) ->
    
    
  
  
  ### ``Interceptor`` sends events through ``app.navigate`` when appropriate.
  ###
  class Interceptor
    
    # patterns matching external links to ignore
    ignore_patterns: [
      /^\/api/,
      /^\/app/,
      /^\/backend/,
      /^\/static/
    ]
    # test whether to ignore
    shouldIgnore: (url, target) ->
      return true if not url?
      return true for item in @ignore_patterns when url.match item
      return true if target.attr('rel') is 'external'
      false
      
    
    # test whether the link click came from a back button
    shouldTriggerBack: (target) ->
      target.attr 'rel' is 'back'
      
    
    
    # dispatch to app.navigate, catching errors so we stay within the app
    dispatch: (url) ->
      try
        app.navigate url, true
      catch err
        console.error err
      
    
    # send links straight through
    handleLink: (url) ->
      @dispatch url
      
    
    # send form posts through with the data added to the query string
    handleForm: (url, query) ->
      parts = url.split('?')
      if parts.length is 2
        existing_data = $.parseQuery parts[1]
        form_data = $.parseQuery query
        merged_data = _.extend existing_data form_data
        query = $.param merged_data
      url = "#{parts[0]}?#{query}"
      @dispatch url
      
    
    
    # bind to ``click``, ``dblclick`` and ``submit`` events
    constructor: ->
      $('body').bind 'click dblclick submit', (event) =>
          target = $ event.target
          if event.type is 'submit'
            url = target.attr('action')
            @handleForm url, target.serialize() if not @shouldIgnore url, target
          else
            url = target.attr('href')
            if @shouldTriggerBack target
              window.history.go -1
            else
              @handleLink url if not @shouldIgnore url, target
          return false
          
      
      
    
  
  
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
        
        # initialise the controller
        controller = new Controller null, current_user, current_query, \
                                    messages, here, current_location
        
        # start handling requests
        Backbone.history.start pushState: true
        
        # start intercepting events
        interceptor = new Interceptor
        
        # provide ``app.navigate``
        exports.navigate = controller.navigate
        
      , ->
        
        # XXX show a proper user interface here
        alert 'togethr needs to know your location'
        window.location.reload()
      
    
    
  
  exports.main = main
  


### Provide ``app.main`` as ``window.togethr.main``.
###
window.togethr ?= {}
window.togethr.main = app.main

