### ...
###
namespace 'user', (exports) ->
  
  class User extends Backbone.Model
    
    localStorage: new Store 'user'
    
  
  exports.User = User
  


