### XXX n.b.:
  * how we render new pages / re-write views
  * whether we keep old pages or re-render on back
  * how we handle live messages flowing in
  * how we handle link catching / ignoring /app, /api, /static, /backend
###
$.namespace 'app', (exports) ->
  
  ### Declare app global variables.
  ###
  current_user = null
  current_location = null
  location_button = null
  
  ### `router` handles URL changes.
  ###
  Router = Backbone.Router.extend
    routes:
      '/': 'home'
    
    home: ->
      # XXX
    
    setLocation: ->
      # XXX
    
  router = new Router
  
  ### `bootstrap()` instantiates components once the initial user and location
    state has been established.
  ###
  bootstrap = ->
    location_button = new view.LocationButton model: current_location
    # XXX etc.
    Backbone.history.start pushState: true
    
  
  
  ### Call `app.main({...})` with any initial JSON data.
  ###
  main = (data) ->
    current_user = new model.User data.user ? {}
    current_location = new model.Location
    if data.location
      current_location.set data.location
      bootstrap()
    else
      current_location.setToCurrent -> 
          bootstrap()
        , -> 
          router.setLocation()
        
      
    
  
  exports.main = main
  

