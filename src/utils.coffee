_           = require('underscore')
ScribeDOM   = require('./dom')


ScribeUtils =
  BLOCK_TAGS: [
    'ADDRESS'
    'BLOCKQUOTE'
    'DD'
    'DIV'
    'DL'
    'H1', 'H2', 'H3', 'H4', 'H5', 'H6'
    'LI'
    'OL'
    'P'
    'PRE'
    'TABLE'
    'TBODY'
    'TD'
    'TFOOT'
    'TH'
    'THEAD'
    'TR'
    'UL'
  ]

  findAncestor: (node, checkFn) ->
    while node? && !checkFn(node)
      node = node.parentNode
    return node

  findDeepestNode: (node, offset) ->
    if node.firstChild?
      for child in _.clone(node.childNodes)
        length = ScribeUtils.getNodeLength(child)
        if offset < length
          return ScribeUtils.findDeepestNode(child, offset)
        else
          offset -= length
      return ScribeUtils.findDeepestNode(child, offset + length)
    else
      return [node, offset]
        
  getChildAtOffset: (node, offset) ->
    child = node.firstChild
    length = ScribeUtils.getNodeLength(child)
    while child?
      break if offset < length
      offset -= length
      child = child.nextSibling
      length = ScribeUtils.getNodeLength(child)
    unless child?
      child = node.lastChild
      offset = ScribeUtils.getNodeLength(child)
    return [child, offset]

  getNodeLength: (node) ->
    return 0 unless node?
    if node.nodeType == ScribeDOM.ELEMENT_NODE
      return _.reduce(node.childNodes, (length, child) ->
        return length + ScribeUtils.getNodeLength(child)
      , if ScribeUtils.isLineNode(node) then 1 else 0)
    else if node.nodeType == ScribeDOM.TEXT_NODE
      return ScribeDOM.getText(node).length
    else
      return 0

  isBlock: (node) ->
    return _.indexOf(ScribeUtils.BLOCK_TAGS, node.tagName, true) > -1

  isLineNode: (node) ->
    return node?.parentNode?.parentNode?.tagName == "BODY" and ScribeUtils.isBlock(node)

  removeFormatFromSubtree: (subtree, format) ->
    if format.matchContainer(subtree)
      subtree = ScribeDOM.unwrap(subtree)
    _.each(subtree.childNodes, (child) ->
      ScribeUtils.removeFormatFromSubtree(child, format)
    )
    return subtree

  # Firefox needs splitBefore, not splitAfter like it used to be, see doc/selection
  splitBefore: (node, root) ->
    return false if node == root or node.parentNode == root
    parentNode = node.parentNode
    parentClone = parentNode.cloneNode(false)
    parentNode.parentNode.insertBefore(parentClone, parentNode)
    while node.previousSibling?
      parentClone.insertBefore(node.previousSibling, parentClone.firstChild)
    ScribeUtils.splitBefore(parentNode, root)

  splitNode: (node, offset, force = false) ->
    # Check if split necessary
    nodeLength = ScribeUtils.getNodeLength(node)
    offset = Math.max(0, offset)
    offset = Math.min(offset, nodeLength)
    return [node.previousSibling, node, false] unless force or offset != 0
    return [node, node.nextSibling, false] unless force or offset != nodeLength
    if node.nodeType == ScribeDOM.TEXT_NODE
      after = node.splitText(offset)
      return [node, after, true]
    else
      left = node
      right = node.cloneNode(false)
      node.parentNode.insertBefore(right, left.nextSibling)
      [child, offset] = ScribeUtils.getChildAtOffset(node, offset)
      [childLeft, childRight] = ScribeUtils.splitNode(child, offset)
      while childRight != null
        nextRight = childRight.nextSibling
        right.appendChild(childRight)
        childRight = nextRight
      return [left, right, true]

  traversePostorder: (root, fn, context = fn) ->
    return unless root?
    cur = root.firstChild
    while cur?
      ScribeUtils.traversePostorder.call(context, cur, fn)
      cur = fn.call(context, cur)
      cur = cur.nextSibling if cur?

  traversePreorder: (root, offset, fn, context = fn, args...) ->
    return unless root?
    cur = root.firstChild
    while cur?
      nextOffset = offset + ScribeUtils.getNodeLength(cur)
      curHtml = cur.innerHTML
      cur = fn.call(context, cur, offset, args...)
      ScribeUtils.traversePreorder.call(null, cur, offset, fn, context, args...)
      if cur? && cur.innerHTML == curHtml
        cur = cur.nextSibling
        offset = nextOffset

  traverseSiblings: (curNode, endNode, fn) ->
    while curNode?
      nextSibling = curNode.nextSibling
      fn(curNode)
      break if curNode == endNode
      curNode = nextSibling


module.exports = ScribeUtils
