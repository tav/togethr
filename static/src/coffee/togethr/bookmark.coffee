### ...
###
namespace 'bookmark', (exports) ->
  
  class Bookmark extends Backbone.Model
    localStorage: new Store 'bookmarks'
    
  class Bookmarks extends Backbone.Collection
    model: Bookmark
    localStorage: new Store 'bookmarks'
    
  exports.Bookmark = Bookmark
  exports.Bookmarks = Bookmarks
  


