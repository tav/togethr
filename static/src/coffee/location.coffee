### ...
###
namespace 'location', (exports) ->
  
  if not Number::toRad?
    Number::toRad = -> this * Math.PI / 180
  
  if not Number::toDeg?
    Number::toDeg = -> this * 180 / Math.PI
  
  ### Get the coordinates of a point an ``angle`` and ``distance`` from
    an original point -- see http://bit.ly/qssyw6
  ### 
  getCoordsFrom = (coords, angle, distance) ->
    ### Note, tested with the following code::
      
          c1 =
            latitude: 51.5197572
            longitude: -0.1407846
          
          bbox1 = getBoundaryBox(c1, 30)
          bbox2 = getBoundaryBox(c1, 2)
          
          c2 = getCentre(bbox1)
          c3 = getCentre(bbox2)
          
          console.log c1
          console.log c2
          console.log c3
      
      I get::
      
          Object { latitude=51.5197572, longitude=-0.1407846}
          Object { latitude=51.51935762281386, longitude=-0.13950031168702975}
          Object { latitude=51.51975542413611, longitude=-0.140778892072933}
      
      Which puts me two streets out over 30km.  So it's *not perfect* but
      hopefully is good enough for a *single conversion*, i.e.: unless we start
      converting to and from points and bboxes willy nilly.
      
    ###
    radius = 6371
    d = distance / radius
    a = angle.toRad()
    lat1 = coords.latitude.toRad()
    lon1 = coords.longitude.toRad()
    lat2 = Math.asin(
      Math.sin(lat1) * Math.cos(d) + Math.cos(lat1) \
      * Math.sin(d) * Math.cos(a)
    )
    lon2 = lon1 + Math.atan2(
      Math.sin(a) * Math.sin(d) * Math.cos(lat1),
      Math.cos(d) - Math.sin(lat1) * Math.sin(lat2)
    )
    lon2 = (lon2 + 3 * Math.PI) % (2 * Math.PI) - Math.PI
    coords2 = 
      latitude: lat2.toDeg()
      longitude: lon2.toDeg()
    coords2
    
  
  
  ### Get a boundary box from a centre and distance.
  ###
  getBoundaryBox = (centre, distance) ->
    ne = getCoordsFrom(centre, 45, distance)
    sw = getCoordsFrom(centre, 225, distance)
    bbox = [
      ne.longitude, 
      ne.latitude, 
      sw.longitude, 
      sw.latitude
    ]
    bbox
    
  
  
  ### Get the centre  from a point and distance.
  ###
  getCentre = (bbox) ->
    centre = 
      latitude: (bbox[3] + bbox[1]) / 2 # average of the left and right
      longitude: (bbox[0] + bbox[2]) / 2 # average of the top and bottom
    centre
    
  
  
  ### ``Backbone.Model`` class that encapsulates a specific location.
  ###
  class Location extends Backbone.Model
    ### attributes =
        centre: latitude: 0.0, longitude: 0.0
        bbox: [
          0, # top
          0, # right
          0, # bottom
          0 # left
        ]
        label: ''
      
    ###
    
    # factory class method to create with centre derived from bbox
    @createFromBBox: (bbox, label) ->
      DEFAULT_DISTANCE = 30 # km
      new @
        centre: getCentre(bbox)
        bbox: bbox
        label: label
      
    
    
    # factory class method to create a ``Location`` with bbox derived from centre
    @createFromCoords: (coords, label) ->
      DEFAULT_DISTANCE = 30 # km
      new @
        centre: coords, 
        bbox: getBoundaryBox(coords, DEFAULT_DISTANCE)
        label: label
      
    
    
  
  class LocationButton extends Backbone.View
    
    events:
      click: 'changeLocation'
    
    initialize: ->
      @model.bind 'change', @render
      @model.view = this
      @render()
    
    render: =>
      $ @el .text "+#{@model.get 'label'}"
      
    
    changeLocation: =>
      app.navigate 'location', true
      
    
    
  
  exports.Location = Location
  exports.LocationButton = LocationButton
  

