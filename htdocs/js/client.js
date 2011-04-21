$.togethr = {};

$(document).ready(
  function(){
    
    $(":text").labelify();
    
    $('.coding .commits').githubInfoWidget({
        'user': 'tav', 
        'repo': 'togethr', 
        'branch': 'master', 
        'last': 5
      }
    );
    
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
    };
    
    $.togethr.get_tweets = function (location, since_id) {
      
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
            //console.log(data);
            //window.setTimeout('$.togethr.get_tweets', 60000, location, data['max_id']);
          }
        }
      );
      
    };
    var store_location = function (location) {
      $.cookie(
        'togethr-ll', 
        location.latitude + ',' + location.longitude
      );
    };
    
    var doit = function (location) {
      render_streetview(location);
      render_map(location);
      $.togethr.get_tweets(location);
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