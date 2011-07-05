### XXX n.b.:
  * how we render new pages / re-write views
  * whether we keep old pages or re-render on back
  * how we handle live messages flowing in
  * how we handle link catching / ignoring /app, /api, /static, /backend
###
$.namespace 'app', (exports) ->
  
  ### Declare app global variables.
  ###
  user = null
  here = null
  location = null
  space = null
  context = null
  messages = null
  contextView = null
  message = null
  messageView = null
  dialog = null
  dialogView = null
  
  ### Regexp patterns.
  ###
  patterns =
    badge: /@\w+\/\w+/g
    user: /@\w+/g
    hashtag: /#\w+/g
    place: /\+\w+/g
    challenge: /\/\w+/g
    
  ### ``Router`` handles URL changes.
    
    set location
    select action
    	checkin
    	appreciate
    	badge
    	send message
    	volunteer
    	offer
    	custom
    select view
    	activity stream
    	map
    	network graph
    	tag cloud
    message
    	appreciate
    	jump to
    bookmarks
    settings
    
  ###
  Router = Backbone.Router.extend
    routes:
      ''                            : 'home'
      'space'                       : 'space'
      #'challenge/:challenge'        : 'challenge'
      'message/:msgid'              : 'message'
      'dialog/location'             : 'setLocation'
      #'dialog/jump_to'              : 'jumpTo'
      #':user/:badge'                : 'badge'
      #':user'                       : 'user'
      
    
    ###
      if not current context:
        update context
        update messages
      scroll to top
      show context view
    ###
    home: ->
      currentTitle = context.title
      newTitle = ''
      if currentTitle is not newTitle
        new_context = model.Context
          location: here
          space: new model.Space
          title: newTitle
        messages.reset()
        context.set new_context.toJSON()
      content_view.scrollToTop()
      content_view.show()
      
    
    ###
      if not current context:
        parse query
        update context
        update messages
      scroll to title bar
      show context view
    ###
    space: ->
      currentTitle = context.title
      newTitle = query.split(/\s+/g).sort().join(' ')
      if currentTitle is not newTitle
        # parse the query into structured data
        locationAliases, space = this._parseQuery = []
        space = new model.Space
        spaceAspects =
          badge: patterns.badge
          user: patterns.user
          hashtag: patterns.hashtag
          challenge: patterns.challenge
        query = $.parseQuery().q
        for item in query.split(/\s+/)
          if item.match patterns.place
            locationAliases.push item
          else
            match = false
            for own k, v of spaceAspects
              if item.match v
                space["#{k}s"].push item
                match = true
                break
            if not match
              space.keywords.push item
        # XXX todo - unpack locationAliases
        current_context = context
        new_context = model.Context
          location: location # XXX
          space: space
          title: query
        messages.reset()
        context.set new_context.toJSON()
      content_view.scrollToTitleBar()
      content_view.show()  
    
    ###
      if not current message:
        update current message -> triggers message view render
      show message view
    ###
    message: ->
      # ...
      
    
    ###
      update current dialog -> triggers dialog view render
      show dialog view
    ###
    setLocation: ->
      # ...
      
    
    ### Instantiate views and start handling location changes.
    ###
    initialize: ->
      contextView = new view.ContextView
        context: context
        messages: messages
      messageView = new view.MessageView
        model: message
      dialogView = new view.DialogView
        model: dialog
      Backbone.history.start pushState: true
      
    
  
  router = new Router
  
  ### Call ``app.main({...})`` with any initial JSON data.
  ###
  main = (data) ->
    user = new model.User data.user ? {}
    location = new model.Location data.location ? {}
    candidate = new model.Location data.here ? {}
    space = new model.Space data.space ? {}
    message = new model.Message data.message ? {}
    messages = new model.Messages data.messages ? []
    if data.here
      here = candidate
    else
      candidate.setToHere -> here = candidate
    
  
  exports.router = router
  exports.main = main
  

