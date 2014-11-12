Nali.extend Router:

  initialize: ->
    @::expand redirect: ( args... ) => @redirect args...
    @

  routes:      {}

  start: ->
    @scanRoutes()
    @_( window ).on 'popstate', ( event ) =>
      event.preventDefault()
      event.stopPropagation()
      @saveHistory false
      @redirect event.target.location.pathname
    @

  scanRoutes: ->
    for name, controller of @Controller.extensions when controller.actions?
      route  = '^'
      route += name.lower().replace /s$/, 's*(\/|$)'
      route += '('
      route += Object.keys( controller._actions ).join '|'
      route += ')?'
      @routes[ route ] = controller
    @

  redirect: ( url = window.location.pathname, options = {} ) ->
    if found = @findRoute @prepare( url ) or @prepare( @Application.defaultUrl )
      { controller, action, filters, params } = found
      params[ name ] = value for name, value in options
      controller.run action, filters, params
    else if @Application.notFoundUrl
      @redirect @Application.notFoundUrl
    else console.warn "Not exists route to the address %s", url
    @

  prepare: ( url ) ->
    url = url.replace "http://#{ window.location.host }", ''
    url = url[ 1.. ]   or '' if url and url[ 0...1 ] is '/'
    url = url[ ...-1 ] or '' if url and url[ -1.. ]  is '/'
    url

  findRoute: ( url ) ->
    for route, controller of @routes when match = url.match new RegExp route, 'i'
      segments = ( @routedUrl = url ).split( '/' )[ 1... ]
      if segments[0] in Object.keys( controller._actions )
        action = segments.shift()
      else unless action = controller.actions.default
        console.error 'Unspecified controller action'
      filters = {}
      for name in controller._actions[ action ].filters when segments[0]?
        filters[ name ] = segments.shift()
      params = {}
      for name in controller._actions[ action ].params
        params[ name ] = if segments[0]? then segments.shift() else null
      return controller: controller, action: action, filters: filters, params: params
    false

  saveHistory: ( value ) ->
    @_saveHistory ?= true
    if value in [ true, false ]
      @_saveHistory = value
      @
    else @_saveHistory

  changeUrl: ( url = null ) ->
    if @saveHistory()
      @routedUrl = url if url?
      history.pushState null, null, '/' + ( @url = @routedUrl ) if @routedUrl isnt @url
    else @saveHistory true
    @
