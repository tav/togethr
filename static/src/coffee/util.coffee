### Reusable utility classes.
###
namespace 'util', (exports) ->
  
  ### ``Interceptor`` sends events through ``app.navigate`` when appropriate.
  ###
  class Interceptor
    
    # current domain
    current_host: $.url().attr 'host'
    # patterns matching external links to ignore
    ignore_patterns: [
      /^\/api/,
      /^\/app/,
      /^\/backend/,
      /^\/static/
    ]
    # test whether to ignore and, if not, convert to a relative
    validate: (url, target) ->
      return null if not url?
      parsed = $.url url
      host = parsed.attr 'host'
      relative = parsed.attr 'relative'
      return null if host is not @current_host
      return null for item in @ignore_patterns when relative.match item
      return null if target.attr 'rel' is 'external'
      relative
      
    
    # test whether to go back
    shouldtriggerBack: (target) ->
      return true if target.attr 'rel' is 'back'
      return true if target.closest(":jqmData(rel='back')").length > 0
      false
      
    
    
    # dispatch to app.navigate, catching errors so we stay within the app
    dispatch: (url) ->
      try
        app.navigate url, true
      catch err
        console.error err if console? and console.error?
        
      
    
    
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
      
    
    
    # intercept ``vclick`` and ``submit`` events
    constructor: ->
      $('body').bind 'vclick', (event) =>
          console.log 'intercepted vclick'
          # process an event
          target = $(event.target).closest 'a'
          if @shouldtriggerBack target
            window.history.go -1
          else
            url = @validate target.attr('href'), target
            @handleLink url if url?
          false
        
      
      $('body').bind 'submit', (event) =>
          console.log 'intercepted submit'
          target = $(event.target).closest 'form'
          if @shouldtriggerBack target
            window.history.go -1
          else
            url = @validate target.attr('action'), target
            @handleForm url, target.serialize() if url?
          false
        
      
      
    
    
  
  exports.Interceptor = Interceptor
  


