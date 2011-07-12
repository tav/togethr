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
  
  class Dialog extends Page
  
  exports.Widget = Widget
  exports.Page = Page
  exports.Dialog = Dialog
  


