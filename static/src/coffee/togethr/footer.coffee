### ...
###
namespace 'footer', (exports) ->
  
  class FooterWidget extends mobone.view.Widget
    
    act_path: 'app/select/action'
    
    events:
      'click .act-button': 'handleActButtonClick'
    
    initialize: ->
      bar = @$ '.menu-bar'
      bar.navbar()
      
    
    
    handleActButtonClick: (event) =>
      path = Backbone.history.getFragment()
      ends_with = path.charAt(path.length - 1)
      path = "#{path}/" if not (ends_with is '/')
      app.navigate "#{path}#{@act_path}", true
      false
      
    
    
  
  exports.FooterWidget = FooterWidget
  


