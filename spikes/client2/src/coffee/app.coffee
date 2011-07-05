$.namespace 'app', (exports) ->
  
  class Controller
    
    ### Apply backbone views to existing pages when created.
    ###
    create: (event, page) ->
      console.log 'create', page.id
      switch page.id
        when 'query'
          @queryView = new query.QueryPage
            el: page
            query: @query
            location: @location
        #when 'message'
        #  @messageView = new message.MessagePage
        #    el: page 
        # else ...
      
    
    
    ### ...
    ###
    startup: (event, page, prev) ->
      console.log 'startup', page.id
      switch page.id
        when 'query'
          q = $.parseQuery().q ? 'XXX'
          @query.set 'value': q
          console.log 'set q to ', q
        
      
    
    ### ...
    ###
    shutdown: (event, page, next) ->
      console.log 'shutdown', page.id
    
    
    ### ...
    ###
    show: (event, page, prev) ->
      console.log 'show', page.id
    
    
    ### ...
    ###
    hide: (event, page, next) ->
      console.log 'hide', page.id
    
    
    ### ...
    ###
    constructor: (data) ->
      @user = new user.User data.user ? {}
      @query = new query.Query data.query ? {}
      @location = new loc.Location data.location ? bbox: ['1', '2', '3', '4'] # XXX
      target = $ 'div' 
      target.live 'pagecreate', (e) => @create e, e.target
      target.live 'pagebeforeshow', (e, ui) => @startup e, e.target, ui.prevPage
      target.live 'pagebeforehide', (e, ui) => @shutdown e, e.target, ui.nextPage
      target.live 'pageshow', (e, ui) => @show e, e.target, ui.prevPage
      target.live 'pagehide', (e, ui) => @hide e, e.target, ui.nextPage
      
    
    
  exports.Controller = Controller
  

