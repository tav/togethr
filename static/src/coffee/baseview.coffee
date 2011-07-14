### Base ``Backbone.View`` classes.
###
namespace 'baseview', (exports) ->
  
  class Widget extends Backbone.View
    
    # wake
    restore: (args...) -> # noop
    # sleep
    snapshot: (args...) -> # noop
    
    # show
    show: (args...) -> $(@el).show()
    # hide
    hide: (args...) -> $(@el).hide()
    
  
  class Page extends Widget
    
    constructor: ->
      super
      @el.bind 'pagebeforeshow', (e, ui) => @restore e, e.target, ui.prevPage
      @el.bind 'pagebeforehide', (e, ui) => @snapshot e, e.target, ui.nextPage
      @el.live 'pageshow', (e, ui) => @show e, e.target, ui.prevPage
      @el.live 'pagehide', (e, ui) => @hide e, e.target, ui.nextPage
      
    
    
  
  class Dialog extends Page
    
  
  exports.Widget = Widget
  exports.Page = Page
  exports.Dialog = Dialog
  


