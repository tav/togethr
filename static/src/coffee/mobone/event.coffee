# `mobone.event` provides utilities for handling events.
mobone.namespace 'mobone.event', (exports) ->
  
  # ``Interceptor`` binds to `click` and `submit` events and:
  # 
  # * ignores external urls and urls matching `ignore_patterns`
  # * prevents default on urls matching `prevent_default_patterns`
  # * stops back links and triggers `history.back()`
  # * stops and routes everything else through app.navigate
  # 
  # Configure by passing in the following as `options`:
  # 
  # * `ignore_patterns`: regexp patterns matching urls to ignore
  # * `prevent_default_patterns`: patterns matching urls to prevent default on
  # * `external_selectors`: jquery selectors matching external links
  # * `back_selectors`: selectors matching back links
  # 
  # By default, binds to `vclick submit` events on document.body.  To bind to
  # a different element pass in `target_selector`. To override the events
  # bound to pass in `bind_events` (although bear in mind all events that are
  # not 'submit' will be handled as if they come from links with an href.
  class Interceptor
    options:
      ignore_patterns: [
        # Ignore `/api`, `/system`, `/backend` and `/static`.
        /^\/api/, 
        /^\/system/, 
        /^\/backend/, 
        /^\/static/
      ]
      prevent_default_patterns: [
        # Prevent default on all links starting with a `#`.
        /^#/
      ]
      external_selectors: [
        # Treat events from elements with `rel="external"` as external links.
        '[rel="external"]',
        '[data-rel="external"]',
        ':jqmData(rel="external")'
      ]
      back_selectors: [
        # Treat events from elements with `rel="back"` as back links.
        '[rel="back"]',
        '[data-rel="back"]',
        ':jqmData(rel="back")'
      ]
      target_selector: 'body'
      bind_events: 'vclick submit'
      
    # Current domain.
    current_host: $.url().attr 'host'
    
    # Dispatch to `app.navigate()`, catching errors so we stay within the app.
    dispatch: (path) ->
      try
        app.navigate path, true
      catch err
        console.error err if console? and console.error?
        
      
    
    # Send links straight through to `dispatch()`.
    handleLink: ->
      @dispatch @path
      
    
    # Send form posts through with the data added to the query string.
    handleForm: ->
      # Get the form data.
      query = @target.serialize()
      # If there's also data in the query string...
      parts = @path.split('?')
      if parts.length is 2
        # ... merge the form data and the query string together.
        existing_data = $.parseQuery parts[1]
        form_data = $.parseQuery query
        merged_data = _.extend existing_data form_data
        query = $.param merged_data
      # Encode the data into the query string and dispatch.
      path = "#{parts[0]}?#{query}"
      @dispatch path
      
    
    
    # `shouldIgnore()` external urls and urls matching `ignore_patterns`.
    shouldIgnore: ->
      patterns = @options.ignore_patterns
      selectors = @options.external_selectors
      return true for item in patterns when @path.match item
      return true for item in selectors when @target.closest(item).length > 0
      false
      
    
    # `shouldPreventDefault()` on urls matching `prevent_default_patterns`.
    shouldPreventDefault: ->
      patterns = @options.prevent_default_patterns
      return true for item in patterns when @path.match item 
      false
      
    
    # `shouldtriggerBack()` when target matches `back_selectors`.
    shouldtriggerBack: ->
      selectors = @options.external_selectors
      return true for item in selectors when @target.closest(item).length > 0
      false
      
    
    
    # Convert a url to its relative path, as long as it comes from this domain.
    relative: (url) ->
      return null if not url?
      parsed = $.url url
      host = parsed.attr 'host'
      relative = parsed.attr 'relative'
      return null if host is not @current_host
      relative
      
    
    
    # `handle()` an event by getting the `target` element that triggered it,
    # the url as a relative `path` and then using those to work out whether
    # to ignore, prevent default, trigger back or dispatch to `app.navigate`.
    handle: (event) =>
      
      if event.type is 'submit'
        tag_name = 'form'
        attr_name = 'action'
      else
        tag_name = 'a'
        attr_name = 'href'
      
      @target = $(event.target).closest tag_name
      @path = @relative @target.attr attr_name
      
      return true if not @path?
      return true if @shouldIgnore()
      
      if @shouldPreventDefault()
        event.preventDefault()
        return true
      
      if @shouldtriggerBack()
        window.history.back()
        return false
      
      if event.type is 'submit' then @handleForm() else @handleLink()
      return false
      
    
    # Intercept and handle `@options.bind_events`.
    constructor: (options) ->
      _.extend(@options, options) if options?
      target = $ @options.target_selector
      target.bind @options.bind_events, @handle
      
    
    
  
  exports.Interceptor = Interceptor
  


