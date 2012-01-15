# Public Domain (-) 2011 The Togethr Authors.
# See the Togethr UNLICENSE file for details.

define 'togethr', (exports, root) ->

  doc = root.document
  events = {}
  evid = 1
  isArray = Array.isArray

  propFix =
    cellpadding: "cellPadding"
    cellspacing: "cellSpacing"
    class: "className"
    colspan: "colSpan"
    contenteditable: "contentEditable"
    for: "htmlFor"
    frameborder: "frameBorder"
    maxlength: "maxLength",
    readonly: "readOnly"
    rowspan: "rowSpan"
    tabindex: "tabIndex"
    usemap: "useMap"

  buildDOM = (data, parent) ->
    l = data.length
    if l >= 1
      tag = data[0] # TODO(tav): use this to check which attrs are valid.
      elem = doc.createElement tag
      parent.appendChild elem
    if l >= 2
      attrs = data[1]
      start = 1
      if !isArray(attrs) and typeof attrs is 'object'
        for k, v of attrs
          type = typeof v
          if k.lastIndexOf('on', 0) is 0
            if type isnt 'function'
              continue
            if !elem.__evi
              elem.__evi = evid++
            if events[elem.__evi]
              events[elem.__evi].push [v, false]
            else
              events[elem.__evi] = [[v, false]]
            elem.addEventListener k.slice(2), v, false
          else
            elem[propFix[k] or k] = v
        start = 2
      for child in data[start...l]
        type = typeof child
        if type is 'string'
          elem.appendChild document.createTextNode child
        else
          buildDOM child, elem
    return

  exports.domly = (data, target) ->
    frag = doc.createDocumentFragment()
    buildDOM data, frag
    target.appendChild frag
    return

  return
