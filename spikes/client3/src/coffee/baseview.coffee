### Base ``Backbone.View`` classes.
###
namespace 'baseview', (exports) ->
  
  class Page extends Backbone.View
    
    # override to wake view from sleep
    wake: (args...) -> # noop
    
    # override to sleep view
    sleep: (args...) -> # noop
    
    # show view
    show: (args...) -> $(@el).show()
    
    # hide view
    hide: (args...) -> $(@el).hide()
    
  
  class Dialog extends Page
    
  
  exports.Page = Page
  exports.Dialog = Dialog
  

