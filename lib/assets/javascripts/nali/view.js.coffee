Nali.extend View:
  
  extension: ->
    if @sysname isnt 'View'
      @parseTemplate()
      @parseEvents() 
    @ 
    
  cloning: ->
    @my = @model
    @
  
  layout: -> null
  
  onSourceUpdated:   -> @draw()
    
  onSourceDestroyed: -> @hide()
  
  getOf: ( source, property ) ->
    @subscribeTo source, "update.#{ property }", @onSourceUpdated
    source[ property ]
    
  insertTo: ->
    if ( layout = @layout() )?.childOf? 'View' then layout.show().element.find '.yield'
    else @Application.htmlContainer
  
  draw: ->
    assistant.call @ for assistant in @assistants
    @onDraw?()
    @
    
  show: ( insertTo = @insertTo() ) ->
    @prepareElement().draw().bindEvents()
    unless @visible
      @model.beforeShow?[ @sysname ]?.call @model
      @subscribeTo @model, 'update',  @onSourceUpdated
      @subscribeTo @model, 'destroy', @onSourceDestroyed
      @element.appendTo insertTo
      @showRelations()
      setTimeout ( => @onShow() ), 5 if @onShow?
      @visible = true
      @model.afterShow?[ @sysname ]?.call @model
    @
          
  hide: ( delay = 0 ) ->
    if @visible
      @model.beforeHide?[ @sysname ]?.call @model
      @hideDelay = delay if typeof( delay ) is 'number' and delay
      @onHide?()
      @trigger 'hide'
      @hideElement()
      @destroyObservation()
      @visible = false
      @model.afterHide?[ @sysname ]?.call @model
    @
    
  hideElement: ->
    if @hideDelay? then setTimeout ( => @removeElement() ), @hideDelay else @removeElement()
    @
  
  removeElement: ->
    @element[0].parentNode.removeChild @element[0]
    @
    
  showRelations: ->
    for { selector, name, view } in @relationsMap
      if ( relation = @model[ name ] )? 
        insertTo = @element.find selector
        if relation.childOf 'Collection'
          relation.show view, insertTo, true
          relation.subscribeTo @, 'hide', relation.reset 
        else
          view = relation.show view, insertTo
          view.subscribeTo @, 'hide', view.hide
      else console.warn "Relation %s does not exist of model %O", name, @model
    @
    
  runLink: ( event ) ->
    event.preventDefault()
    @runUrl event.currentTarget.getAttribute 'href'
    @

  runForm: ( event ) ->
    event.preventDefault()
    @runUrl event.currentTarget.getAttribute( 'action' ), @formToHash event.currentTarget 
    @
    
  runUrl: ( url, params = {} ) ->
    if match = url.match /^(@@?)(.+)/
      [ method, data ] = match[2].split '?'
      if data
        for specification in data.split /&|&amp;/ when specification
          [ name, value ] = specification.split '='
          params[ name ]  = value
      obj = if match[1].length is 1 then @ else @model
      if obj[ method ]? and typeof obj[ method ] is 'function' then obj[ method ] params
      else console.warn "Method %s not exists", method
    else @Router.go url, params
    @
  
  formToHash: ( form ) ->
    params = {}
    for element in form.elements
      if name = element.name or element.id
        property = ( keys = name.match /[^\[\]]+/g ).pop()
        target   = params
        for key in keys
          target = if target[ key ] instanceof Object then target[ key ] else target[ key ] = {}
        target[ property ] = element.value
    params
    
  parseEvents: ->
    @eventsMap = []
    if @events
      @events = [ @events ] if typeof @events is 'string'
      for event in @events
        try
          [ handlers, type, other ] = event.split /\s+(on|one)\s+/ 
          [ events, selector ]      = other.split /\s+at\s+/ 
          handlers = handlers.split /\s*,\s*/
          events   = events.replace /\s*,\s*/, ' '
          throw true unless type and events.length and handlers.length
        catch 
          console.warn "Events parsing error: \"%s\" of %O", event, @
          error = true
        if error then error = false else @eventsMap.push [ selector, type, events, handlers ]
    @

  bindEvents: ->
    unless @binded?
      @element.find( 'a'    ).on 'click',  ( event ) => @runLink event
      @element.find( 'form' ).on 'submit', ( event ) => @runForm event
      @element.on 'click',  ( event ) => @runLink event if @element.is 'a' 
      @element.on 'submit', ( event ) => @runForm event if @element.is 'form' 
      for [ selector, type, events, handlers ] in @eventsMap
        for handler in handlers
          do ( selector, type, events, handler ) =>
            @element[ type ] events, selector, ( event ) => @[ handler ] event 
      @binded = true
    @
  
  prepareElement: ->
    unless @element
      @element         = @_ @template
      @element[0].view = @
      @addAssistants()
    @
    
  getNode: ( path ) ->
    node = @element[0]
    node = node[ sub ] for sub in path
    node  
    
  parseTemplate: ->
    if container = document.querySelector '#' + @sysname.underscore() 
      @template = container.innerHTML.trim().replace( /\s+/g, ' ' )
        .replace( /({\s*\+.+?\s*})/g, ' <assist>$1</assist>' )
        .replace( /{\s*yield\s*}/g, '<div class="yield"></div>' )
      unless RegExp( "^<[^>]+" + @sysname ).test @template
        @template = "<div class=\"#{ @sysname }\">#{ @template }</div>"
      @parseRelations()
      container.parentNode.removeChild container
    else console.warn 'Template %s not exists', @sysname
    @
  
  parseRelations: ->
    @relationsMap = []
    @template = @template.replace  /{\s*(\w+) of @(\w+)\s*}/g, ( match, view, relation ) => 
      className =  relation.capitalize() + view.capitalize() + 'Relation'
      @relationsMap.push selector: '.' + className, name: relation, view: view
      "<div class=\"#{ className }\"></div>"
    @parseAssistants()
    @
    
  parseAssistants: ->
    @assistantsMap = []
    if /{\s*.+?\s*}|bind=".+?"/.test @template
      tmp = document.createElement 'div'
      tmp.innerHTML = @template
      @scanAssistants tmp.children[0]
    @
  
  scanAssistants: ( node, path = [] ) ->
    if node.nodeType is 3 and /{\s*.+?\s*}/.test node.textContent
      @assistantsMap.push nodepath: path, type: 'Text'
    else if node.nodeName is 'ASSIST'
      @assistantsMap.push nodepath: path, type: 'Html'
    else 
      if node.attributes
        for attribute, index in node.attributes 
          if attribute.name is 'bind'
            @assistantsMap.push nodepath: path, type: 'Form'
          else if /{\s*.+?\s*}/.test attribute.value
            @assistantsMap.push nodepath: path.concat( 'attributes', index ), type: 'Attr'
      @scanAssistants child, path.concat 'childNodes', index for child, index in node.childNodes
    @
  
  addAssistants: ->
    @assistants = []
    @[ "add#{ type }Assistant" ] @getNode nodepath for { nodepath, type } in @assistantsMap
    @
      
  addTextAssistant: ( node ) ->
    initialValue = node.textContent
    @assistants.push -> node.textContent = @analize initialValue
    @
    
  addAttrAssistant: ( node ) ->
    initialValue = node.value
    @assistants.push -> node.value = @analize initialValue
    @
    
  addHtmlAssistant: ( node ) ->
    parent       = node.parentNode
    initialValue = node.innerHTML
    index        = Array::indexOf.call parent.childNodes, node
    after        = parent.childNodes[ index - 1 ] or null
    before       = parent.childNodes[ index + 1 ] or null
    @assistants.push ->
      start = if after  then Array::indexOf.call( parent.childNodes, after ) + 1 else 0
      end   = if before then Array::indexOf.call parent.childNodes, before  else parent.childNodes.length
      parent.removeChild node for node in Array::slice.call( parent.childNodes, start, end )
      parent.insertBefore element, before for element in @_( @analize initialValue )
    @
    
  addFormAssistant: ( node ) ->
    if bind = @analizeChain node.attributes.removeNamedItem( 'bind' ).value
      [ source, property ] = bind
      if node.type in [ 'text', 'textarea']
        node.value = source[ property ]
        
        @_( node ).on 'change', => 
          ( params = {} )[ property ] = node.value
          source.update params
          source.save() unless node.form?
        
        source.subscribe @, "update.#{ property }", =>
          node.value = source[ property ] if node.value isnt source[ property ]
        
      if node.type in [ 'checkbox', 'radio' ]
        node.checked = source[ property ] + '' is node.value
        
        @_( node ).on 'change', => 
          if node.checked is true
            ( params = {} )[ property ] = node.value
            source.update params
            source.save() unless node.form?
              
        source.subscribe @, "update.#{ property }", =>
          node.checked = source[ property ] + '' is node.value
      
      if node.type is 'select-one'
        option.selected = true for option in node when source[ property ] + '' is option.value
        
        @_( node ).on 'change', => 
          ( params = {} )[ property ] = node.value
          source.update params
          source.save() unless node.form?
              
        source.subscribe @, "update.#{ property }", =>
          option.selected = true for option in node when source[ property ] + '' is option.value
    @
        
        
  analize: ( value ) ->
    value.replace /{\s*(.+?)\s*}/g, ( match, sub ) => @analizeMatch sub
  
  analizeMatch: ( sub ) -> 
    if match = sub.match /^@([\w\.]+)(\?)?$/
      if result = @analizeChain match[1]
        [ source, property ] = result
        source.subscribe? @, "update.#{ property }", @onSourceUpdated if source isnt @model
        if match[2] is '?' 
          if source[ property ] then property else ''  
        else source[ property ]
      else ''
    else if match = sub.match /^[=|\+](\w+)$/
      @helpers?[ match[1] ]?.call @
    else undefined

  analizeChain: ( chain ) ->
    segments = chain.split '.'
    property = segments.pop()
    source   = @model
    for segment in segments
      if segment of source then source = source[ segment ]
      else break
    unless property of source
      console.warn "%s: chain \"%s\" is invalid, \"%s\" is not Object", @sysname, chain, segment
      return null
    [ source, property ]