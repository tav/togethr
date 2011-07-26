# Provides `mobone.namespace` function to define a module namespace.
(->
  # Either use `exports` or `window` as the root object.
  root = if typeof exports isnt 'undefined' then exports else window
  # Provide `mobone` if it doesn't exist already.
  root.mobone ?= {}
  # See https://github.com/jashkenas/coffee-script/wiki/FAQ
  root.mobone.namespace = (target, name, block) ->
    # If an explicit target isn't passed in, default to using `root`.
    [target, name, block] = [root, arguments...] if arguments.length < 3
    top = target
    target = target[item] or= {} for item in name.split '.'
    block target, top
    
  
)()
