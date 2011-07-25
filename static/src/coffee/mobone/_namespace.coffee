### See https://github.com/jashkenas/coffee-script/wiki/FAQ
###
namespace = (target, name, block) =>
  [target, name, block] = [(if typeof exports isnt 'undefined' then exports else window), arguments...] if arguments.length < 3
  top = target
  target = target[item] or= {} for item in name.split '.'
  block target, top
  

