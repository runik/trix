#= require trix/operations/image_preload_operation

class Trix.Attachment extends Trix.Object
  @previewablePattern: /^image(\/(gif|png|jpe?g)|$)/

  @attachmentForFile: (file) ->
    attributes = @attributesForFile(file)
    attachment = new this attributes
    attachment.setFile(file)
    attachment

  @attributesForFile: (file) ->
    new Trix.Hash
      filename:    file.name
      filesize:    file.size
      contentType: file.type

  @fromJSON: (attachmentJSON) ->
    new this attachmentJSON

  constructor: (attributes = {}) ->
    super
    @attributes = Trix.Hash.box(attributes)
    @didChangeAttributes()

  getAttribute: (attribute) ->
    @attributes.get(attribute)

  hasAttribute: (attribute) ->
    @attributes.has(attribute)

  getAttributes: ->
    @attributes.toObject()

  setAttributes: (attributes = {}) ->
    newAttributes = @attributes.merge(attributes)
    unless @attributes.isEqualTo(newAttributes)
      @attributes = newAttributes
      @didChangeAttributes()
      @previewDelegate?.attachmentDidChangeAttributes?(this)
      @delegate?.attachmentDidChangeAttributes?(this)

  didChangeAttributes: ->
    if @isPreviewable()
      @preloadURL()

  isPending: ->
    @file? and not (@getURL() or @getHref())

  isInline: ->
    @getContentType() is "inline" and /^data:text\/html/.test(@getURL())

  isPreviewable: ->
    if @attributes.has("previewable")
      @attributes.get("previewable")
    else
      @constructor.previewablePattern.test(@getContentType())

  getType: ->
    if @isInline()
      "inline"
    else if @hasContent()
      "content"
    else if @isPreviewable()
      "preview"
    else
      "file"

  getURL: ->
    @attributes.get("url")

  setURL: (url) ->
    @setAttributes(url: url?.toString())

  getHref: ->
    @attributes.get("href")

  getFilename: ->
    @attributes.get("filename") ? ""

  getFilesize: ->
    @attributes.get("filesize")

  getFormattedFilesize: ->
    filesize = @attributes.get("filesize")
    if typeof filesize is "number"
      Trix.config.fileSize.formatter(filesize)
    else
      ""

  getExtension: ->
    @getFilename().match(/\.(\w+)$/)?[1].toLowerCase()

  getContentType: ->
    @attributes.get("contentType")

  hasHTMLRepresentation: ->
    @isInline() or @hasContent()

  getHTMLRepresentation: ->
    if @isInline()
      @getInlineHTML()
    else
      @getContent()

  getInlineHTML: ->
    Trix.DataUri.parse(@getURL())?.getData() ? ""

  setInlineHTML: (html) ->
    @setURL(new Trix.DataUri("text/html", btoa(html))) if @isInline()

  hasContent: ->
    @attributes.has("content")

  getContent: ->
    @attributes.get("content")

  getWidth: ->
    @attributes.get("width")

  getHeight: ->
    @attributes.get("height")

  getFile: ->
    @file

  setFile: (@file) ->
    if @isPreviewable()
      @preloadFile()

  releaseFile: =>
    @releasePreloadedFile()
    @file = null

  getUploadProgress: ->
    @uploadProgress ? 0

  setUploadProgress: (value) ->
    unless @uploadProgress is value
      @uploadProgress = value
      @uploadProgressDelegate?.attachmentDidChangeUploadProgress?(this)

  toJSON: ->
    @getAttributes()

  getCacheKey: ->
    [super, @attributes.getCacheKey(), @getPreviewURL()].join("/")

  # Previewable

  getPreviewURL: ->
    @previewURL or @preloadingURL

  setPreviewURL: (url) ->
    unless url is @getPreviewURL()
      @previewURL = url
      @previewDelegate?.attachmentDidChangeAttributes?(this)
      @delegate?.attachmentDidChangePreviewURL?(this)

  preloadURL: ->
    @preload(@getURL(), @releaseFile)

  preloadFile: ->
    if @file
      @fileObjectURL = URL.createObjectURL(@file)
      @preload(@fileObjectURL)

  releasePreloadedFile: ->
    if @fileObjectURL
      URL.revokeObjectURL(@fileObjectURL)
      @fileObjectURL = null

  preload: (url, callback) ->
    if url and url isnt @getPreviewURL()
      @preloadingURL = url
      operation = new Trix.ImagePreloadOperation url
      operation.then ({width, height}) =>
        @setAttributes({width, height})
        @preloadingURL = null
        @setPreviewURL(url)
        callback?()
