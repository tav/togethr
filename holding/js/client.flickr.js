var renderbgimage = function (data) {
  if ('photos' in data) {
    var photos = data['photos']['photo'];
    var large_photos = $.grep(
      photos, 
      function (item) {
        return 'url_l' in item;
      }
    );
    var i = Math.floor(Math.random()*large_photos.length);
    var item = large_photos[i];
    $('body').prepend(
      '<img src="' + item['url_l'] + '" class="bg" />'
    );
  }
};

$(document).ready(
  function(){
    
    $(":text").labelify();
    
    var get_background_image = function (location) {
      console.log(location);
      var d = new Date();
      var one_year = 1000 * 60 * 60 * 24 * 365;
      var one_year_ago = d.getTime() - one_year;
      var lat = location.latitude;
      var lon = location.longitude;
      var a = '9a3f4728054b2cf3efbb32bd943f503d';
      var t = '72157626530299844-4262997cd80ba07a';
      var s = '4705ddbbfd2d826a';
      var g = $.md5(
        s + 
        'accuracy11' + 
        'api_key' + a + 
        'auth_token' + t + 
        'content_type1' +
        'extrasdate_upload,date_taken,license,url_z,url_l,url_o' + 
        'formatjson' +
        //'is_commonstrue' +
        'jsoncallbackrenderbgimage' +
        'lat' + lat + 
        //'license7' +
        'lon' + lon + 
        'methodflickr.photos.search' +
        'min_taken_date2000' +
        'radius30' +
        'safe_search2' +
        'tagsarchitecture,city,town,place,landmark,street,streets,outdoors'
      );
      var url = 'http://api.flickr.com/services/rest/';
      var params = {
        'accuracy': '11',
        'api_key': a,
        'auth_token': t,
        'content_type': 1,
        'extras': 'date_upload,date_taken,license,url_z,url_l,url_o',
        'format': 'json',
        //'is_commons': true,
        'lat': lat,
        //'license': 7,
        'lon': lon,
        'method': 'flickr.photos.search',
        'min_taken_date': '2000',
        'radius': '30',
        'safe_search': 2,
        'tags': 'architecture,city,town,place,landmark,street,streets,outdoors',
        'api_sig': g
      };
      $.ajax(
        url, {
          'cache': true,
          'data': params,
          'dataType': 'jsonp', 
          'jsonp': 'jsoncallback',
          'jsonpCallback': 'renderbgimage'
        }
      );
    };
    
    var store_location = function (location) {
      $.cookie(
        'togethr-ll', 
        location.latitude + ',' + location.longitude
      );
    };
    
    var default_location = {
      'latitude': 51.5001524,
      'longitude': -0.1262362
    };
    
    /*
    var ll = $.cookie('togethr-ll');
    if (ll) {
      var parts = ll.split(',');
      var location = {
        'latitude': parts[0],
        'longitude': parts[1]
      };
      get_background_image(location);
    }
    else {
    */
    
    console.log('*');
    
      $.geolocation.find(
        function (location) {
          
          // store_location(location);
          // get_background_image(location);
          
          http://search.twitter.com/search.json?geocode=37.781157,-122.398720,1mi
          
          var url = 'http://maps.google.com/maps/api/staticmap';
          var params = {
            'center': location.latitude + ',' + location.longitude,
            'format': 'png32',
            'zoom': '12',
            'size': '640x640',
            'sensor': false
          };
          var img = '<img src="' + url + '?' + $.param(params) + '" class="bg" />';
          $('body').prepend(img);
        },
        function () {
          // get_background_image(default_location);
        }
      );
    //}
    
});