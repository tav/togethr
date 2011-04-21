(function ($) {
  function widget(element, options) {
    this.element = element;
    this.options = options;
  }
  
  widget.prototype = (function() {
    
    function _widgetRun(widget) {
      if (!widget.options) {
        widget.element.append('<span class="error">Options for widget are not set.</span>');
        return;
      }
    
      var element = widget.element;
      var user = widget.options.user;
      var repo = widget.options.repo;
      var branch = widget.options.branch;
      var last = widget.options.last == undefined ? 0 : widget.options.last;
      var limitMessage = widget.options.limitMessageTo == undefined ? 0 : widget.options.limitMessageTo;
      
      element.append('<h3>Widget intitalization, please wait...</h3>');
      gh.commit.forBranch(user, repo, branch, function (data) {
        var commits = data.commits;
        var totalCommits = (last < commits.length ? last : commits.length);
        
        element.empty();
        
        for (var c = 0; c < totalCommits; c++) {
          var msg = commits[c].message;
          if (msg.length > 65) {
            msg = commits[c].message.substr(0, 60) + ' &hellip;';
          } 
          element.append(
            '<li class="article">' +
              '<div class="metadata">' +
                '<div class="via"><span>commit:&nbsp;</span><a href="https://github.com' + commits[c].url + '">' + commits[c].id.substr(0, 8) + ' &hellip;</a></div>' +
                '<div class="via"><span>tree:</span><a href="https://github.com/tav/togethr/tree/' + commits[c].id + '">' + commits[c].tree.substr(0, 8) + ' &hellip;</a></div>' +
              '</div>' +
              '<div class="avatar-box">' +
                '<a href="https://github.com/' + commits[c].author.login + '">' +
                  avatar(commits[c].author.email) + 
                '</a>' +
              '</div>' +
              '<div class="update">' +
                '<div class="user">' + author(commits[c].author.login) + '</div>' +
                '<div class="message">' + msg + '</div>' +
                '<div class="when">' + when(commits[c].committed_date) + '</div>' +
              '</div>' +
              '<div class="clear"></div>' +
            '</li>'
          );
        }
        
        function avatar(email) {
          var emailHash = $.md5(email);
          return '<img src="http://www.gravatar.com/avatar/' + emailHash + '?s=50"/>';
        }
        
        function author(login) {
          return '<a href="https://github.com/' + login + '">' + login + '</a>';
        }
        
        function message(commitMessage, url) {
          if (limitMessage > 0 && commitMessage.length > limitMessage)
          {
            commitMessage = commitMessage.substr(0, limitMessage) + '...';
          }
          return '"' + '<a href="https://github.com' + url + '">' + commitMessage + '</a>"';
        }
        
        function when(commitDate) {
          var commitTime = new Date(commitDate).getTime();
          var todayTime = new Date().getTime();
          
          var differenceInDays = Math.floor(((todayTime - commitTime)/(24*3600*1000)));
          if (differenceInDays == 0) {
            var differenceInHours = Math.floor(((todayTime - commitTime)/(3600*1000)));
            if (differenceInHours == 0) {
              var differenceInMinutes = Math.floor(((todayTime - commitTime)/(600*1000)));
              if (differenceInMinutes == 0) {
                
                return 'just now';
              }
              
              return 'about ' + differenceInMinutes + ' minutes ago';
            }
            
            return 'about ' + differenceInHours + ' hours ago';
          }
          
          return differenceInDays + ' days ago';
        }
      });
    }
    
    return {
      run: function () {
        _widgetRun(this);
      }
    };
    
  })();

  $.fn.githubInfoWidget = function(options) {
    var w = new widget(this, options);
    w.run();
    
    return this;
  }
  
})(jQuery);