### Base ``Backbone.View`` classes.
###
mobone.namespace 'mobone.view', (exports) ->
  
  class BaseView extends Backbone.View
    
    # All views must provide this API.
    snapshot: -> #
    restore: -> #
    show: -> #
    hide: -> #
    
  
  class Widget extends BaseView
    
    show: -> $(@el).show()
    hide: -> $(@el).hide()
    
  
  class Page extends BaseView
    
    constructor: ->
      super
      @el.bind 'pagebeforeshow', (e, ui) => @restore e, e.target, ui.prevPage
      @el.bind 'pagebeforehide', (e, ui) => @snapshot e, e.target, ui.nextPage
      @el.bind 'pageshow', (e, ui) => @show e, e.target, ui.prevPage
      @el.bind 'pagehide', (e, ui) => @hide e, e.target, ui.nextPage
      
    
    
  
  class Dialog extends Page
  
  # `RelativeButton` binds to `vclick` events and uses a `data-relative-path`
  # attribute to set the `target.attr 'href'` to a relative path.
  class RelativeButton extends Backbone.View
    
    
    # Bind to `vclick` events.
    events: 
      'vclick': 'handleClick'
    
    # `handleClick` overrides the `target.href` using the current location path
    # + `target.data 'relative-path'`.
    handleClick: (event) =>
      # Get the anchor element.
      target = $(event.target).closest 'a'
      return if not target.length > 0
      # Make sure it has an `relative_path`.
      relative_path = target.data 'relative-path'
      return if not relative_path?
      # Get the current location path.
      location_path = window.location.pathname
      # Put the two together
      if not location_path.endsWith '/'
        location_path = "#{location_path}/"
      if relative_path.startsWith '/'
        relative_path = relative_path.slice 1
      href = "#{location_path}#{relative_path}"
      # Set the `href` attribute on the event `target`.
      target.attr 'href', href
      
    
    
  
  
  exports.Widget = Widget
  exports.Page = Page
  exports.Dialog = Dialog
  exports.RelativeButton = RelativeButton
  


