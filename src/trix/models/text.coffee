#= require trix/models/piece
#= require trix/models/piece_list
#= require trix/utilities/hash

class Trix.Text
  @textForAttachmentWithAttributes: (attachment, attributes) ->
    piece = Trix.Piece.forAttachment(attachment, attributes)
    new this [piece]

  @textForStringWithAttributes: (string, attributes) ->
    piece = new Trix.Piece string, attributes
    new this [piece]

  @fromJSONString: (string) ->
    @fromJSON JSON.parse(string)

  @fromJSON: (textJSON) ->
    pieces = for pieceJSON in textJSON
      Trix.Piece.fromJSON pieceJSON
    new this pieces, textJSON.attributes

  constructor: (pieces = [], attributes = {}) ->
    @editDepth = 0
    @pieceList = new Trix.PieceList pieces

  edit = (fn) -> ->
    @beginEditing()
    fn.apply(this, arguments)
    @endEditing()

  beginEditing: ->
    @editDepth++
    this

  endEditing: ->
    if --@editDepth is 0
      @pieceList.consolidate()
      @delegate?.didEditText?(this)
    this

  edit: edit (fn) -> fn()

  appendText: edit (text) ->
    @insertTextAtPosition(text, @getLength())

  insertTextAtPosition: edit (text, position) ->
    @pieceList.insertPieceListAtPosition(text.pieceList, position)

  removeTextAtRange: edit (range) ->
    @pieceList.removePiecesInRange(range)

  replaceTextAtRange: edit (text, range) ->
    @removeTextAtRange(range)
    @insertTextAtPosition(text, range[0])

  replaceText: edit (text) ->
    @pieceList.mergePieceList(text.pieceList)

  moveTextFromRangeToPosition: edit (range, position) ->
    return if range[0] <= position <= range[1]
    text = @getTextAtRange(range)
    length = text.getLength()
    position -= length if range[0] < position
    @removeTextAtRange(range)
    @insertTextAtPosition(text, position)

  addAttributeAtRange: edit (attribute, value, range) ->
    attributes = {}
    attributes[attribute] = value
    @addAttributesAtRange(attributes, range)

  addAttributesAtRange: edit (attributes, range) ->
    @pieceList.transformPiecesInRange range, (piece) ->
      piece.copyWithAdditionalAttributes(attributes)

  removeAttributeAtRange: edit (attribute, range) ->
    @pieceList.transformPiecesInRange range, (piece) ->
      piece.copyWithoutAttribute(attribute)

  setAttributesAtRange: edit (attributes, range) ->
    @pieceList.transformPiecesInRange range, (piece) ->
      piece.copyWithAttributes(attributes)

  getAttributesAtPosition: (position) ->
    @pieceList.getPieceAtPosition(position)?.getAttributes() ? {}

  getCommonAttributesAtRange: (range) ->
    @pieceList.getPieceListInRange(range)?.getCommonAttributes() ? {}

  getExpandedRangeForAttributeAtRange: (attributeName, range) ->
    [left, right] = range
    originalLeft = left
    length = @getLength()

    left-- while left > 0 and @getCommonAttributesAtRange([left - 1, right])[attributeName]
    right++ while right < length and @getCommonAttributesAtRange([originalLeft, right + 1])[attributeName]

    [left, right]

  getTextAtRange: (range) ->
    new @constructor @pieceList.getPieceListInRange(range).toArray()

  getStringAtRange: (range) ->
    @pieceList.getPieceListInRange(range).toString()

  getAttachments: ->
    @pieceList.getAttachments()

  getAttachmentById: (attachmentId) ->
    {attachment, position} = @pieceList.getAttachmentAndPositionById(attachmentId)
    attachment

  getRangeOfAttachment: (attachment) ->
    {attachment, position} = @pieceList.getAttachmentAndPositionById(attachment.id)
    [position, position + 1] if attachment?

  resizeAttachmentToDimensions: (attachment, {width, height} = {}) ->
    if range = @getRangeOfAttachment(attachment)
      @addAttributesAtRange({width, height}, range)

  getLength: ->
    @pieceList.getLength()

  isEqualTo: (text) ->
    this is text or text?.pieceList?.isEqualTo(@pieceList)

  eachRun: (callback) ->
    position = 0
    @pieceList.eachPiece (piece) ->
      id = piece.id
      attributes = piece.getAttributes()
      run = {id, attributes, position}

      if piece.attachment
        run.attachment = piece.attachment
      else
        run.string = piece.toString()

      callback(run)
      position += piece.length

  inspect: ->
    @pieceList.inspect()

  copy: ->
    new @constructor @pieceList.toArray()

  toString: ->
    @pieceList.toString()

  toJSON: ->
    @pieceList

  asJSON: ->
    JSON.stringify(this)
