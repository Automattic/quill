Scribe = require('./scribe')


Scribe.DOM = 
  ELEMENT_NODE: 1
  NOBREAK_SPACE:  "&nbps;"
  TEXT_NODE: 3
  ZERO_WIDTH_NOBREAK_SPACE:  "\uFEFF"

  addClass: (node, cssClass) ->
    return if Scribe.DOM.hasClass(node, cssClass)
    if node.classList?
      node.classList.add(cssClass)
    else if node.className?
      node.className += ' ' + cssClass

  addEventListener: (node, eventName, listener) ->
    if node.addEventListener?
      return node.addEventListener(eventName, listener)
    else if node.attachEvent?
      if _.indexOf(['change', 'click', 'focus', 'keydown', 'keyup', 'mousedown', 'mouseup', 'paste'], eventName) > -1
        return node.attachEvent("on#{eventName}", listener)
    throw new Error("Cannot attach to unsupported event #{eventName}")

  findDeepestNode: (node, offset) ->
    if node.firstChild?
      for child in _.clone(node.childNodes)
        length = Scribe.Utils.getNodeLength(child)
        if offset < length
          return Scribe.DOM.findDeepestNode(child, offset)
        else
          offset -= length
      return Scribe.DOM.findDeepestNode(child, offset + length)
    else
      return [node, offset]

  getClasses: (node) ->
    if node.classList
      return _.clone(node.classList)
    else if node.className?
      return node.className.split(' ')

  getText: (node) ->
    switch node.nodeType
      when Scribe.DOM.ELEMENT_NODE
        return if node.tagName == "BR" then "" else node.textContent or node.innerText or ""
      when Scribe.DOM.TEXT_NODE then return node.data or ""
      else return ""

  hasClass: (node, cssClass) ->
    if node.classList?
      return node.classList.contains(cssClass)
    else if node.className?
      return _.indexOf(Scribe.DOM.getClasses(node), cssClass) > -1
    return false

  mergeNodes: (node1, node2) ->
    return node2 if !node1?
    return node1 if !node2?
    this.moveChildren(node1, node2)
    node2.parentNode.removeChild(node2)
    if (node1.tagName == 'OL' || node1.tagName == 'UL') && node1.childNodes.length == 2
      Scribe.DOM.mergeNodes(node1.firstChild, node1.lastChild)
    return node1

  moveChildren: (newParent, oldParent) ->
    _.each(_.clone(oldParent.childNodes), (child) ->
      newParent.appendChild(child)
    )

  normalize: (node) ->
    # Credit: Tim Down - http://stackoverflow.com/questions/2023255/node-normalize-crashes-in-ie6
    child = node.firstChild
    while (child)
      if (child.nodeType == 3)
        while ((nextChild = child.nextSibling) && nextChild.nodeType == 3)
          child.appendData(nextChild.data)
          node.removeChild(nextChild)
      child = child.nextSibling

  removeAttributes: (node, exception = []) ->
    exception = [exception] if _.isString(exception)
    _.each(_.clone(node.attributes), (attrNode, value) ->
      node.removeAttribute(attrNode.name) unless _.indexOf(exception, attrNode.name) > -1
    )

  removeClass: (node, cssClass) ->
    return unless Scribe.DOM.hasClass(node, cssClass)
    if node.classList?
      return node.classList.remove(cssClass)
    else if node.className?
      classArray = Scribe.DOM.getClasses(node)
      classArray.splice(_.indexOf(classArray, cssClass), 1)
      node.className = classArray.join(' ')

  resetSelect: (select) ->
    option = select.querySelector('option[selected]')
    if option?
      option.selected = true
    else
      # IE8
      for o,i in select.options
        if o.defaultSelected
          return select.selectedIndex = i

  setText: (node, text) ->
    switch node.nodeType
      when Scribe.DOM.ELEMENT_NODE
        if node.textContent?
          node.textContent = text
        else
          node.innerText = text
      when Scribe.DOM.TEXT_NODE then node.data = text
      else return # Noop

  # Firefox needs splitBefore, not splitAfter like it used to be, see doc/selection
  splitBefore: (node, root) ->
    return false if node == root or node.parentNode == root
    parentNode = node.parentNode
    parentClone = parentNode.cloneNode(false)
    parentNode.parentNode.insertBefore(parentClone, parentNode)
    while node.previousSibling?
      parentClone.insertBefore(node.previousSibling, parentClone.firstChild)
    Scribe.DOM.splitBefore(parentNode, root)

  splitNode: (node, offset, force = false) ->
    # Check if split necessary
    nodeLength = Scribe.Utils.getNodeLength(node)
    offset = Math.max(0, offset)
    offset = Math.min(offset, nodeLength)
    return [node.previousSibling, node, false] unless force or offset != 0
    return [node, node.nextSibling, false] unless force or offset != nodeLength
    if node.nodeType == Scribe.DOM.TEXT_NODE
      after = node.splitText(offset)
      return [node, after, true]
    else
      left = node
      right = node.cloneNode(false)
      node.parentNode.insertBefore(right, left.nextSibling)
      [child, offset] = Scribe.Utils.getChildAtOffset(node, offset)
      [childLeft, childRight] = Scribe.DOM.splitNode(child, offset)
      while childRight != null
        nextRight = childRight.nextSibling
        right.appendChild(childRight)
        childRight = nextRight
      return [left, right, true]

  switchTag: (node, newTag) ->
    return if node.tagName == newTag
    newNode = node.ownerDocument.createElement(newTag)
    this.moveChildren(newNode, node)
    node.parentNode.replaceChild(newNode, node)
    newNode.className = node.className if node.className
    newNode.id = node.id if node.id
    return newNode

  toggleClass: (node, className) ->
    if Scribe.DOM.hasClass(node, className)
      Scribe.DOM.removeClass(node, className)
    else
      Scribe.DOM.addClass(node, className)

  traversePostorder: (root, fn, context = fn) ->
    return unless root?
    cur = root.firstChild
    while cur?
      Scribe.DOM.traversePostorder.call(context, cur, fn)
      cur = fn.call(context, cur)
      cur = cur.nextSibling if cur?

  traversePreorder: (root, offset, fn, context = fn, args...) ->
    return unless root?
    cur = root.firstChild
    while cur?
      nextOffset = offset + Scribe.Utils.getNodeLength(cur)
      curHtml = cur.innerHTML
      cur = fn.call(context, cur, offset, args...)
      Scribe.DOM.traversePreorder.call(null, cur, offset, fn, context, args...)
      if cur? && cur.innerHTML == curHtml
        cur = cur.nextSibling
        offset = nextOffset

  traverseSiblings: (curNode, endNode, fn) ->
    while curNode?
      nextSibling = curNode.nextSibling
      fn(curNode)
      break if curNode == endNode
      curNode = nextSibling

  unwrap: (node) ->
    ret = node.firstChild
    next = node.nextSibling
    _.each(_.clone(node.childNodes), (child) ->
      node.parentNode.insertBefore(child, next)
    )
    node.parentNode.removeChild(node)
    return ret

  wrap: (wrapper, node) ->
    node.parentNode.insertBefore(wrapper, node)
    wrapper.appendChild(node)
    return wrapper


module.exports = Scribe
