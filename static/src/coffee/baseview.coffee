### Base ``Backbone.View`` classes.
###
namespace 'baseview', (exports) ->
  
  class BaseView extends Backbone.View
    
    # All views must provide this API.
    snapshot: -> #
    restore: -> #
    show: -> #
    hide: -> #
    
  
  
  class Widget extends BaseView
    
    show: (args...) -> $(@el).show()
    hide: (args...) -> $(@el).hide()
    
  
  
  class Page extends BaseView
    
    constructor: ->
      super
      @el.bind 'pagebeforeshow', (e, ui) => @restore e, e.target, ui.prevPage
      @el.bind 'pagebeforehide', (e, ui) => @snapshot e, e.target, ui.nextPage
      @el.bind 'pageshow', (e, ui) => @show e, e.target, ui.prevPage
      @el.bind 'pagehide', (e, ui) => @hide e, e.target, ui.nextPage
      
    
    
  
  class Dialog extends Page
    
  
  exports.Widget = Widget
  exports.Page = Page
  exports.Dialog = Dialog
  


