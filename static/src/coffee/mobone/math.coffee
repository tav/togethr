namespace 'mobone.math', (exports) ->
  
  # Generate a UUID (see http://www.broofa.com/Tools/Math.uuid.js).
  uuid = ->
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
        r = Math.random() * 16 | 0
        v = if c is 'x' then r else r&0x3|0x8
        v.toString 16
      
    
  
  
  exports.uuid = uuid
  

