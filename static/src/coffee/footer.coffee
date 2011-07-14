### ...
###
namespace 'footer', (exports) ->
  
  class FooterWidget extends baseview.Widget
    initialize: ->
      bar = @$ '.menu-bar'
      bar.navbar()
      
    
  
  exports.FooterWidget = FooterWidget
  


