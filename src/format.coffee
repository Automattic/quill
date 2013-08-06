_         = require('underscore')
ScribeDOM = require('./dom')


class ScribeLeafFormat
  constructor: (@root, @keyName) ->

  clean: (node) ->
    ScribeDOM.removeAttributes(node)

  createContainer: (value) ->
    throw new Error("Descendants should implement")

  matchContainer: (container) ->
    throw new Error("Descendants should implement")


class ScribeTagFormat extends ScribeLeafFormat
  constructor: (@root, @keyName, @tagName) ->
    super

  createContainer: (value) ->
    return @root.ownerDocument.createElement(@tagName)

  matchContainer: (container) ->
    return container.tagName == @tagName


class ScribeSpanFormat extends ScribeTagFormat
  constructor: (@root, @keyName) ->
    super(@root, @keyName, 'SPAN')


class ScribeClassFormat extends ScribeSpanFormat
  constructor: (@root, @keyName) ->
    super

  clean: (node) ->
    ScribeDOM.removeAttributes(node, 'class')

  createContainer: (value) ->
    container = super(value)
    ScribeDOM.addClass(container, "#{@keyName}-#{value}")
    return container

  matchContainer: (container) ->
    if super(container)
      classList = ScribeDOM.getClasses(container)
      for css in classList
        parts = css.split('-')
        if parts.length > 1 and parts[0] == @keyName
          return parts.slice(1).join('-')
    return false


class ScribeStyleFormat extends ScribeSpanFormat
  @getStyleObject: (container) ->
    styleString = container.getAttribute('style') or ''
    return _.reduce(styleString.split(';'), (styles, str) ->
      [name, value] = str.split(':')
      if name and value
        name = name.slice(1) if name.slice(0, 1) == " "
        value = value.slice(1) if value.slice(0, 1) == " "
        styles[name.toLowerCase()] = value
      return styles
    , {})

  @getCamelCase: (cssName) ->
    nameArr = cssName.split('-')
    capitalNameArr = _.map(nameArr, (name) ->
      return name[0].toUpperCase() + name.slice(1)
    )
    return nameArr[0] + capitalNameArr.slice(1).join('')

  constructor: (@root, @keyName, @cssName, @styles, @matchFn) ->
    @matchFn or= (cssValue) =>
      for key,value of @styles
        return key if value.toUpperCase() == cssValue.toUpperCase()
      return false
    super

  clean: (node) ->
    ScribeDOM.removeAttributes(node, 'style')

  createContainer: (value) ->
    container = super(value)
    return container unless @styles[value]?
    cssName = ScribeStyleFormat.getCamelCase(@cssName)
    container.style[cssName] = @styles[value] if @styles[value]
    return container

  matchContainer: (container) ->
    return false unless super(container)
    styles = ScribeStyleFormat.getStyleObject(container)
    return if styles[@cssName]? then @matchFn(styles[@cssName]) else false


class ScribeBoldFormat extends ScribeTagFormat
  constructor: (@root) ->
    super(@root, 'bold', 'B')


class ScribeItalicFormat extends ScribeTagFormat
  constructor: (@root) ->
    super(@root, 'italic', 'I')


class ScribeStrikeFormat extends ScribeTagFormat
  constructor: (@root) ->
    super(@root, 'strike', 'S')


class ScribeUnderlineFormat extends ScribeTagFormat
  constructor: (@root) ->
    super(@root, 'underline', 'U')


class ScribeLinkFormat extends ScribeTagFormat
  constructor: (@root) ->
    super(@root, 'link', 'A')

  clean: (node) ->
    ScribeDOM.removeAttributes(node, ['href', 'title'])

  createContainer: (value) ->
    link = super(value)
    value = 'http://' + value unless value.match(/^https?:\/\//)
    link.href = value
    link.href = 'about:blank' if (link.protocol != 'http:' && link.protocol != 'https:')
    link.title = link.href
    return link

  matchContainer: (container) ->
    return if super(container) then container.getAttribute('href') else false


class ScribeBackgroundFormat extends ScribeStyleFormat
  constructor: (@root) ->
    colors = _.clone(ScribeColorFormat.COLORS)
    delete colors['white']
    super(@root, 'background', 'background-color', colors, ScribeColorFormat.matchColor)


class ScribeColorFormat extends ScribeStyleFormat
  @COLORS: {
    'black'   : '#000000'
    'red'     : '#FF0000'
    'blue'    : '#0000FF'
    'lime'    : '#00FF00'
    'teal'    : '#00FFFF'
    'magenta' : '#FF00FF'
    'yellow'  : '#FFFF00'
    'white'   : '#FFFFFF'
  }

  @normalizeColor: (color) ->
    color = ScribeColorFormat.COLORS[color] if ScribeColorFormat.COLORS[color]?
    if color[0] == '#'
      if color.length == 4
        color = '#' + _.map(color.slice(1), (letter) ->
          letter + letter
        ).join('')
      return color
    else if color.indexOf('rgb(') == 0
      color = color.slice(4)
      color = _.reduce(color.split(',').slice(0, 3), (color, part) ->
        c = parseInt(part, 10).toString(16).toUpperCase()
        c = '0' + c if c.length == 1
        return color + c
      , '#')
      return color
    else
      return '#000000'

  @matchColor: (cssValue) ->
    color = ScribeColorFormat.normalizeColor(cssValue)
    for key,value of @styles
      return key if value.toUpperCase() == color.toUpperCase()
    return false

  constructor: (@root) ->
    colors = _.clone(ScribeColorFormat.COLORS)
    delete colors['black']
    super(@root, 'color', 'color', colors, ScribeColorFormat.matchColor)


class ScribeFamilyFormat extends ScribeStyleFormat
  constructor: (@root) ->
    super(@root, 'family', 'font-family', {
      'serif'     : "'Times New Roman', serif"
      'monospace' : "'Courier New', monospace"
    }, (cssValue) =>
      for key,value of @styles
        return key if value.indexOf(key) > -1
      return false
    )


class ScribeSizeFormat extends ScribeStyleFormat
  constructor: (@root) ->
    super(@root, 'size', 'font-size', {
      'huge'  : '32px'
      'large' : '18px'
      'small' : '10px'
    })

  createContainer: (value) ->
    container = super(value)
    return container


module.exports = 
  Leaf  : ScribeLeafFormat
  Tag   : ScribeTagFormat
  Span  : ScribeSpanFormat
  Class : ScribeClassFormat
  Style : ScribeStyleFormat

  Bold      : ScribeBoldFormat
  Italic    : ScribeItalicFormat
  Link      : ScribeLinkFormat
  Strike    : ScribeStrikeFormat
  Underline : ScribeUnderlineFormat
  
  Background  : ScribeBackgroundFormat
  Color       : ScribeColorFormat
  Family      : ScribeFamilyFormat
  Size        : ScribeSizeFormat
