# XXX for now, this is a noop
Backbone.sync = (method, model, options) ->
  
  resp = null
  noop = -> # pass
  
  switch method
    when 'read', 'create', 'update', 'delete' then noop()
    
  if resp
    options.success resp
  else
    options.error 'Record not found'
  

