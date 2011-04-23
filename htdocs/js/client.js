$(document).ready(
  function(){
    
    /*
      
      Tweets - involves a fair bit of hackery
      
      
    */
    
    var when = function (datestring) {
      var t = Date.parse(datestring);
      var n = new Date().getTime();
      var dDays = Math.floor(((n - t)/(24*3600*1000)));
      if (dDays == 0) {
        var dHours = Math.floor(((n - t)/(3600*1000)));
        if (dHours == 0) {
          var dMinutes = Math.floor(((n - t)/(60*1000)));
          if (dMinutes == 0) {
            var dSecs = Math.floor((n - t) / 1000);
            return 'about ' + dSecs + ' seconds ago';
          }
          return 'about ' + dMinutes + ' minutes ago';
        }
        return 'about ' + dHours + ' hours ago';
      }
      return dDays + ' days ago';
    };
    var max_info_window_zindex = 0;
    var max_id_str = null;
    var drag_position = null;
    var timeout = null;
    var cache = {
      'tweets': {},
      'locations': {}
    };
    $.togethr = {};
    $.togethr.get_tweets = function (location, map, since_id) {
      
      var url = 'http://search.twitter.com/search.json';
      var params = {
        'geocode': location.latitude + ',' + location.longitude + ',1mi'
      };
      if (since_id) {
        params['since_id'] = since_id;
      }
      
      $.ajax(
        url, {
          'data': params,
          'dataType': 'jsonp',
          'success': function (data) {
            
            max_id_str = data['max_id_str'];
            var tweets = data['results'].reverse();
            
            $.each(
              tweets,
              function (i, item) {
                
                // make sure we don't render a duplicate
                if (item['id_str'] in cache['tweets'] || item['location'] in cache['locations']) {
                  // pass
                }
                else {
                  // store that we've processed this tweet
                  cache['tweets'][item['id_str']] = true;
                  cache['locations'][item['location']] = true;
                  // get the location
                  var lat = null;
                  var lon = null;
                  var parts = item['location'].split(' ');
                  if (parts.length == 2) {
                    parts = parts[1].split(',');
                    if (parts.length == 2) {
                      if (!isNaN(parseFloat(parts[0])) && !isNaN(parseFloat(parts[1]))) {
                        lat = parseFloat(parts[0]);
                        lon = parseFloat(parts[1]);
                      }
                    }
                  }
                  // if we have a valid location
                  if (lat && lon) {
                    // prepare to render an icon to the map
                    var image = new google.maps.MarkerImage(item['profile_image_url']);
                    image.scaledSize = new google.maps.Size(25, 25);
                    var position = new google.maps.LatLng(lat, lon);
                    var options = {
                        'animation': google.maps.Animation.DROP,
                        'visible': true,
                        'icon': image,
                        'map': map,
                        'position': position
                    };
                    // setting the info window content to correspond to the tweet
                    var text = item['text'];
                    if (text.length > 80) {
                      text = text.substr(0, 75) + ' ...';
                    }
                    var info_content = '<div class="infowindow">' +
                      '<div class="avatar-box">' +
                        '<a href="http://twitter.com/' + item['from_user'] + '">' +
                          '<img src="' + item['profile_image_url'] + '" /></a>' + 
                      '</div>' + 
                      '<div class="content">' +
                        '<a href="http://twitter.com/' + item['from_user'] + '">' +
                          '@' + item['from_user'] + '</a>' +
                        '&nbsp;' + 
                        text +
                      '</div>' +
                      '<div class="when">' +
                        '<a href="http://twitter.com/' + item['from_user'] + 
                            '/status/' + item['id_str'] + '">' + 
                          when(item['created_at']) + '</a>' +
                      '</div>' +
                      '<div class="clear">' +
                      '</div>' +
                    '</div>';
                    var info = new google.maps.InfoWindow({'content': info_content});
                    // actually drop the marker onto the map with a delay based on i
                    // so they fall in one after the other
                    window.setTimeout(
                      function () {
                        var marker = new google.maps.Marker(options);
                        if ($.browser.mozilla && $.browser.version.match(/^2/)) {
                          // hacking the damn thing to be visible in FF4
                          marker.setVisible(false);
                          marker.setVisible(true);
                          var z = parseInt(google.maps.Marker.MAX_ZINDEX) + 2000;
                          marker.setZIndex(z);
                        }
                        // open the info window on click
                        google.maps.event.addListener(
                          marker, 
                          'click', 
                          function() {
                            info.open(map, marker);
                          }
                        );
                        // hack the info window every time it renders, sigh
                        google.maps.event.addListener(
                          info, 
                          'domready', 
                          function () {
                            // hack the damn thing to show the content
                            $(info.Ua.l).attr(
                              'style',
                              $(info.Ua.l).attr('style').replace(/auto/g, 'show')
                            );
                            // hack the damn thing to display ontop
                            var z = info.getZIndex();
                            if (z < max_info_window_zindex) {
                              z = max_info_window_zindex;
                            }
                            z += 1000;
                            max_info_window_zindex = z;
                            info.setZIndex(z)
                          }
                        );
                      },
                      i * 300
                    );
                  }
                }
              }
            );
          }
        }
      );
      
      google.maps.event.addListener(
        map, 
        'center_changed', 
        function () {
          
          // stop any pending call to refresh tweets
          window.clearTimeout(timeout);
          // start looking for tweets again since whenever
          max_id_str = null;
          
          // find out where we are now
          var position = map.getCenter();
          
          // if we haven't already just handled a dragend to this position
          // (i.e.: prevent duplicate events)
          if (!position.equals(drag_position)) {
            
            // get tweets for the current location
            var location = {
              'latitude': position.lat(),
              'longitude': position.lng()
            };
            $.togethr.get_tweets(
              location,
              map,
              null
            );
            
            drag_position = position;
          }
          
        }
      );
      
      // check for more recent tweets every 30 seconds
      timeout = window.setTimeout(
        function () {
          $.togethr.get_tweets(location, map, max_id_str);
        },
        10000
      );
      
    };
    
    /*
      
      Render streetview and render map
      
      n.b.: render_map calls $.togethr.get_tweets for the first time
      to pass through the location and map instance
      
      
    */
    
    var render_streetview = function (location) {
      var ll = new google.maps.LatLng(location.latitude, location.longitude);
      var options = {
        'position': ll,
        'pov': {
          heading: 165,
          pitch: 0,
          zoom: 1
        },
        'addressControl': false,
        'enableCloseButton': false,
        'linksControl': false,
        'panControl': false,
        'zoomControl': false
      };
      var h = $(document).height() - 20;
      var target = $('.streetview .canvas');
      target.css({'height': h});
      var panorama = new google.maps.StreetViewPanorama(target.get(0), options);
      panorama.setVisible(true);
    };
    var render_map = function (location) {
      var ll = new google.maps.LatLng(location.latitude, location.longitude);
      var options = {
        'zoom': 13,
        'disableDefaultUI': true,
        'center': ll,
        'mapTypeId': google.maps.MapTypeId.ROADMAP
      };
      var h = $('.signup .left').height() - 3;
      var target = $('.map .canvas');
      target.css({'height': h});
      var map = new google.maps.Map(target.get(0), options);
      window.setTimeout(
        function () {
          $.togethr.get_tweets(location, map, null);
        },
        1000
      );
    };
    
    /*
      
      We store the user's location once found in a session cookie
      
      
    */
      
    var store_location = function (location) {
      $.cookie(
        'togethr-ll', 
        location.latitude + ',' + location.longitude
      );
    };
    
    /*
      
      Let's do this thing
      
      
    */
    
    // text input label foobar
    $(":text").labelify();
    
    // render commits feed
    $('.coding .commits').githubInfoWidget({
        'user': 'tav', 
        'repo': 'togethr', 
        'branch': 'master', 
        'last': 5
      }
    );
    
    // get the location and do the relevant stuff
    
    var doit = function (location) {
      render_streetview(location);
      render_map(location);
    };
    
    var ll = $.cookie('togethr-ll');
    if (ll) {
      var parts = ll.split(',');
      var location = {
        'latitude': parts[0],
        'longitude': parts[1]
      };
      doit(location);
    }
    else {
      $.geolocation.find(
        function (location) {
          store_location(location);
          doit(location);
        },
        function () {
          var location = {
            'latitude': 51.5001524,
            'longitude': -0.1262362
          };
          doit(location);
        }
      );
    }
    
    
});