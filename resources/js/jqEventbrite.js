/*
 * Eventbrite API client (jQuery required) - https://github.com/ryanjarvinen/Eventbrite.jquery.js
 */

//Constructor
var Eventbrite = function () {
  var args = Array.prototype.slice.call(arguments),
    // the last argument is the callback
    callback = args.pop();
  this.auth_tokens = {};
  if(typeof args[0] === 'object'){
    this.auth_tokens = args[0];
  }else{
    this.auth_tokens.app_key = args[0];
    if(typeof args[1] !== 'function'){
      if(typeof args[2] !== 'function'){
       this.auth_tokens.user = args[1];
       this.auth_tokens.password = args[1];
      }else{
       this.auth_tokens.user_key = args[1];
      }
    }
  }

  // make sure the function is called as a constructor
  if (!(this instanceof Eventbrite)) {
    return new Eventbrite(auth_tokens, callback);
  }

  // call callback
  callback(this);
}

Eventbrite.prototype = {
  'api_host': "https://developer.eventbrite.com/json/",
  'api_methods': ['discount_new', 'discount_update', 'event_copy', 'event_get', 'event_list_attendees', 'event_list_discounts', 'event_new', 'event_search', 'event_update', 'organizer_list_events', 'organizer_new', 'organizer_update', 'organizer_get', 'payment_update', 'ticket_new', 'ticket_update', 'user_get', 'user_list_events', 'user_list_organizers', 'user_list_tickets', 'user_list_venues', 'user_new', 'user_update', 'venue_new', 'venue_get', 'venue_update'],
  'request': function ( method, params, cb ) {
    var auth_headers = {};
    if( this.auth_tokens['access_token'] === undefined ){
        if(this.auth_tokens.app_key){ params.app_key = this.auth_tokens.app_key;}
        if(this.auth_tokens.user_key){ params.user_key = this.auth_tokens.user_key;}
        if(this.auth_tokens.user){ params.user = this.auth_tokens.user;}
        if(this.auth_tokens.password){ params.password = this.auth_tokens.password;}
    }else{
        auth_headers = {'Authorization': 'Bearer ' + this.auth_tokens['access_token']};
        params.access_token = this.auth_tokens.access_token;
    }

    j$.ajax({
      url: this.api_host + method,
      data: params,
      type: 'GET',
      dataType: 'jsonp',
      headers: auth_headers,
      beforeSend: function(xhrObj){
        xhrObj.setRequestHeader("Content-Type","application/json");
        xhrObj.setRequestHeader("Accept","application/json");
        if(params.access_token !== undefined){
          xhrObj.setRequestHeader("Authorization","Bearer "+params.access_token);
        }
      },
      success: function (resp) {
        cb(resp.contents);
      },
      failure: function (err) {
        console.log("Error connecting to Eventbrite API");
      }
    });
  },

  // Widget rendering functions

  'utils': {
    'eventList': function( evnts, callback, options){
      var html = ['<div class="eb_event_list">'];
      if( evnts['events'] !== undefined ){
        var len = evnts['events'].length;
        for( var i = 0; i < len; i++ ){
          if(evnts['events'][i]['event'] !== undefined ){
            html.push( callback( evnts['events'][i]['event'], options ));
          }
        }
      }else{
        html.push('No events are available at this time.');
      }
      html.push('</div>');
      return html.join('\n');
    },
    'eventListRow': function( evnt ){
      var not_iso_8601 = /\d\d-\d\d-\d\d \d\d:\d\d:\d\d/;
      var date_string = not_iso_8601.test( evnt['start_date'] ) ? evnt['start_date'].replace(' ', 'T') : evnt['start_date'];
      var start_date = new Date( Date.parse( date_string ));
      var venue_name = 'Online'; //default location name
      var time_string = Eventbrite.prototype.utils.formatTime( start_date );
      var date_string = start_date.toDateString();
      var html = '';
      if( evnt['venue'] !== undefined && evnt['venue']['name'] !== undefined && evnt['venue']['name'] !== ''){
          venue_name = evnt['venue']['name'];
      }

      html = "<div class='eb_event_list_item' id='evnt_div_" + evnt['id'] + "'>" +
             "<span class='eb_event_list_title'><a href='" + evnt['url'] + "'>" + evnt['title'] + "</a></span>" +
             "<span class='eb_event_list_date'>" + date_string + "</span><span class='eb_event_list_time'>" + time_string + "</span>" +
             "<span class='eb_event_list_location'>" + venue_name + "</span></div>";
      return html;
    },
    'formatTime': function( time ){
      var time_string = '';
      var minutes = time.getMinutes();
      var hours = time.getHours();
      var ampm = 'am';
      if( minutes < 10 ){
        minutes = '0' + minutes;
      }
      if( hours == 0 ){
        hours = 12;
      } else if ( hours >= 12 ){
        ampm = 'pm';
        if( hours !== 12){
          hours = hours - 12;
        }
      }
      return time_string += hours + ':' + minutes + ampm;
    }
  },
  'widget': {
    'ticket': function( evnt ) {
      return '<div style="width:100%; text-align:left;"><iframe  src="http://www.eventbrite.com/tickets-external?eid=' + evnt.id + '&ref=etckt" frameborder="0" height="192" width="100%" vspace="0" hspace="0" marginheight="5" marginwidth="5" scrolling="auto" allowtransparency="true"></iframe><div style="font-family:Helvetica, Arial; font-size:10px; padding:5px 0 5px; margin:2px; width:100%; text-align:left;"><a style="color:#ddd; text-decoration:none;" target="_blank" href="http://www.eventbrite.com/r/etckt">Online Ticketing</a><span style="color:#ddd;"> for </span><a style="color:#ddd; text-decoration:none;" target="_blank" href="http://www.eventbrite.com/event/' + evnt.id + '?ref=etckt">' + evnt.title + '</a><span style="color:#ddd;"> powered by </span><a style="color:#ddd; text-decoration:none;" target="_blank" href="http://www.eventbrite.com?ref=etckt">Eventbrite</a></div></div>';
    },
    'registration': function( evnt ) {
      return '<div style="width:100%; text-align:left;"><iframe  src="http://www.eventbrite.com/event/' + evnt.id + '?ref=eweb" frameborder="0" height="1000" width="100%" vspace="0" hspace="0" marginheight="5" marginwidth="5" scrolling="auto" allowtransparency="true"></iframe><div style="font-family:Helvetica, Arial; font-size:10px; padding:5px 0 5px; margin:2px; width:100%; text-align:left;"><a style="color:#ddd; text-decoration:none;" target="_blank" href="http://www.eventbrite.com/r/eweb">Online Ticketing</a><span style="color:#ddd;"> for </span><a style="color:#ddd; text-decoration:none;" target="_blank" href="http://www.eventbrite.com/event/' + evnt.id + '?ref=eweb">' + evnt.title + '</a><span style="color:#ddd;"> powered by </span><a style="color:#ddd; text-decoration:none;" target="_blank" href="http://www.eventbrite.com?ref=eweb">Eventbrite</a></div></div>';
    },
    'calendar': function ( evnt ) {
      return '<div style="width:195px; text-align:center;"><iframe  src="http://www.eventbrite.com/calendar-widget?eid=' + evnt.id + '" frameborder="0" height="382" width="195" marginheight="0" marginwidth="0" scrolling="no" allowtransparency="true"></iframe><div style="font-family:Helvetica, Arial; font-size:10px; padding:5px 0 5px; margin:2px; width:195px; text-align:center;"><a style="color:#ddd; text-decoration:none;" target="_blank" href="http://www.eventbrite.com/r/ecal">Online event registration</a><span style="color:#ddd;"> powered by </span><a style="color:#ddd; text-decoration:none;" target="_blank" href="http://www.eventbrite.com?ref=ecal">Eventbrite</a></div></div>';
    },
    'countdown': function ( evnt ) {
      return '<div style="width:195px; text-align:center;"><iframe  src="http://www.eventbrite.com/countdown-widget?eid=' + evnt.id + '" frameborder="0" height="479" width="195" marginheight="0" marginwidth="0" scrolling="no" allowtransparency="true"></iframe><div style="font-family:Helvetica, Arial; font-size:10px; padding:5px 0 5px; margin:2px; width:195px; text-align:center;"><a style="color:#ddd; text-decoration:none;" target="_blank" href="http://www.eventbrite.com/r/ecount">Online event registration</a><span style="color:#ddd;"> for </span><a style="color:#ddd; text-decoration:none;" target="_blank" href="http://www.eventbrite.com/event/' + evnt.id + '?ref=ecount">' + evnt.title + '</a></div></div>';
    },
    'button': function ( evnt ) {
      return '<a href="http://www.eventbrite.com/event/' + evnt.id + '?ref=ebtn" target="_blank"><img border="0" src="http://www.eventbrite.com/registerbutton?eid=' + evnt.id + '" alt="Register for ' + evnt.title + ' on Eventbrite" /></a>';
    },
    'link': function ( evnt, text, color ) {
      return '<a href="http://www.eventbrite.com/event/' + evnt.id + '?ref=elink" target="_blank" style="color:' + ( color || "#000000" ) + ';">' + ( text || evnt.title ) + '</a>';
    }
  }
};

(function(){
  var len = Eventbrite.prototype.api_methods.length;
  function addMethod ( method ) {
    Eventbrite.prototype[method] = function( params, callback) {
      this.request( method, params, callback );
    }
  }

  for ( var i = 0; i < len ; i += 1 ){
    addMethod( Eventbrite.prototype.api_methods[i] );
  }
}());
