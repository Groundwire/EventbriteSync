public with sharing class Eventbrite {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2012 Groundwire
* This program is released under the GNU Affero General Public License. http://www.gnu.org/licenses/
*
* Apex class that interprets JSON responses from the Eventbrite API 
* So far, supports the following API calls:
*   - userListEvents
*   - eventListAttendees
*-----------------------------------------------------------------------------------------------*/

	public class Event {
		public string id; 				// The event ID.
		public string title; 			// The event title.
		public string description;		// The event description.
		public string category;			// The event category.
		public string tags;				// The event tags/keywords.
		public datetime start_date;		// The event start date and time, in ISO 8601 format (e.g., “2007-12-31 23:59:59″).
		public datetime end_date;		// The event end date and time, in ISO 8601 format (e.g., “2007-12-31 23:59:59″).
		public string timezone;			// The event timezone.
		public datetime created;		// The date and time the event was created, in ISO 8601 format (e.g., “2007-12-31 23:59:59″).
		public datetime modified;		// The date and time the event was last modified, in ISO 8601 format (e.g., “2007-12-31 23:59:59″).
		public string privacy;			// Private for a private event, Public for a public event.
		public string password;			// Reserved for private event only.
		public integer capacity;		// The total event capacity.
		public integer num_attendee_rows;   // EB says this attribute is not supposed to exist.  But it does.
		public string repeats;
		public string url;				// The event registration URL.
		public string status;			// The event status (“draft”, “live”, “started”, “ended”, or “canceled”).
		public string logo;				// The event logo URL.
		public string logo_ssl;			// The event logo URL for secure applications.
		public string background_color;	// Custom hexadecimal color for your registration page. Format: FFFFFF without the pound
		public string text_color;			
		public string link_color;			
		public string title_text_color;	
		public string box_background_color;
		public string box_text_color;		
		public string box_border_color;	
		public string box_header_background_color;
		public string box_header_text_color;
		public Eventbrite.venue venue;
		public Eventbrite.organizer organizer;
		public list<Eventbrite.ticket> tickets;
	}
	
	public class Venue { 
		public string id;			// The venue ID.
		public string name;			// The venue name.
		public decimal longitude;	// The venue GeoLocation in WGS84 (Longitude).
		public decimal latitude;	// The venue GeoLocation in WGS84 (Latitude).
		public string lat_long;		// NOTE: changed from Lat-Long
		public Eventbrite.Address location;
	}

	public class Address { 
		public string address;		// The venue address.
		public string city;			// The venue city.
		public string region;		// The venue state/province/county depending on the country.
		public string postal_code;	// The venue postal code.
		public string country;		// The venue country name.
		public string country_code;	// The venue country code, in 2-letter ISO 3166 format (e.g., “US”).
	}
		
	public class Organizer {
		public string id;			// The organizer ID.
		public string name;			// The organizer name.
		public string description;	// The organizer description.
		public string url;			// The organizer URL.
	}
	
	public class Ticket {
		public string id;			// The ticket ID.
		public string name;			// The ticket name.
		public string description;	// The ticket description.
		public integer type;		// 0 for fixed-price tickets; 1 for donations.
		public decimal price;		// The ticket price (not provided if the ticket is a donation).

		// The ticket currency, in 3-letter ISO 4217 format (e.g.; “USD”).
		// NOTE: changed from currency to currency_code
		public string currency_code;	

		public integer max;			// The maximum ticket quantity per order for this event
		public integer min;			// The minimum ticket quantity per order for this event.
		public datetime start_date;	// The date and time when ticket sales start
		public datetime end_date;	// The date and time when ticket sales stop
		public integer quantity_available;	// Number of tickets for sale (requires authentication).
		public integer quantity_sold;		// Number of tickets sold (requires authentication).
		public boolean visible;		// Flag indicating if the ticket is visible on the event registration page.
	}

	public class Attendee {
		public string id;				// The attendee record ID. (Incorrectly described in the API Documentation as the event ID.)
		public string event_id;			// The event ID.
		public string ticket_id;		// The ticket ID of the purchased ticket.
		public integer quantity;		// The quantity of tickets purchased.
		public string currency_code;	// The ticket currency, in 3-letter ISO 4217 format (e.g., “USD”).
		public decimal amount_paid;		// The amount paid by the attendee.
		public list<string> barcode;	// list of ticket barcodes (e.g. 0814847311126137001, 0814847311126137002, 0814847311126137003)
		public string order_id;			// The Eventbrite order ID. Not unique among attendee records.
		public string order_type;		// The type/status of order (Free Order, PayPal Completed, Pay By Check, etc).
		public datetime created;		// The date and time that the attendee record was created, in ISO 8601 format (e.g. “2007-12-31 23:59:59″).
		public datetime modified;		// The date and time that the attendee record was last modified, in ISO 8601 format (e.g. “2007-12-31 23:59:59″).
		public datetime event_date;		// Date the attendee has selected. NOTE: Eventbrite returns this for repeat events only.
		public string discount;			// Discount code and amount used by the attendee.
		public string notes;			// Optional notes.
		public string affiliate;		// Undocumented attribute.
		public string email;			// Email address of the attendee.
		public string prefix;			// Prefix of the attendee.
		public string first_name;		// First name of the attendee.
		public string last_name;		// Last name of the attendee.
		public string suffix;			// Suffix of the attendee.
		public string home_phone;		// Home phone of the attendee.
		public string cell_phone;		// Cell phone of the attendee.
		public string work_phone;		// Work phone of the attendee.
		public string company;			// Company of the attendee.
		public string job_title;		// Job title of the attendee.
		public string website;			// Website link of the attendee.
		public string blog;				// Blog of the attendee.
		public string gender;			// Gender of the attendee.
		public date birth_date;			// Birth date of the attendee.
		public integer age;				// Age of the attendee.
		public Eventbrite.Address home_address;
		public Eventbrite.Address work_address;
		public Eventbrite.Address ship_address;
		public list<Eventbrite.Answer> answers;
		public list<Eventbrite.Barcode> barcodes;
	}

	public class Answer {
		public string question_id;		// The question ID.
		public string question;			// The label of the question.
		public string question_type;	// The type of question (“text” or “multiple choice”).
		public string answer_text;		// The answer to the question.
	}

	public class Barcode {
		public string id;				// Same as barcode in attendee
		public string attendee_id;		// Same as id of attendee
		public string status;			// Either "unused" (not checked in) or "used" (checked in)
		public integer checkin_type;	// 1 = Website checkin, 2 = iPhone??, 3 = Android??
		public string checkin_method;
		public string device_id;
		public datetime date_created;
		public datetime date_modified;
	}

	public list<Eventbrite.Event> parseUserListEvents(string js) {
		list<Eventbrite.Event> eventList = new list<Eventbrite.Event>();
		JSONParser jp = JSON.createParser(js);
	    while (jp.nextToken() != null) {
	        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
	            String fieldName = jp.getText();
	            jp.nextToken();
	            if (fieldName == 'error') {
	            	throw new EventbriteException(jp);
	            } else if (fieldName == 'events') {
				    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_ARRAY) {
				        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
				            String fn = jp.getText();
				            jp.nextToken();
				            if (fn == 'event') {
				                eventList.add( parseEvent(jp) );
				            } else {
								ignoreBadProperty( jp, fn );
				            }
				        }
				    }		
	            } else {
					ignoreBadProperty( jp, fieldName );
	            }
	        }
	    }		
	    return eventList;
	}
	
	public Eventbrite.Event parseEvent(string js) {
		return parseEvent( JSON.createParser(js) );
	}
		
	public list<Eventbrite.Attendee> parseEventListAttendees(string js) {
		list<Eventbrite.Attendee> attendeeList = new list<Eventbrite.Attendee>();
		JSONParser jp = JSON.createParser(js);
	    while (jp.nextToken() != null) {
	        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
	            String fieldName = jp.getText();
	            jp.nextToken();
	            if (fieldName == 'error') {
	            	throw new EventbriteException(jp);
	            } else if (fieldName == 'attendees') {
				    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_ARRAY) {
				        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
				            String fn = jp.getText();
				            jp.nextToken();
				            if (fn == 'attendee') {
				                attendeeList.add( parseAttendee(jp) );
				            } else {
								ignoreBadProperty( jp, fn );
				            }
				        }
				    }		
	            } else {
					ignoreBadProperty( jp, fieldName );
	            }
	        }
	    }		
	    return attendeeList;
	}

	public Eventbrite.Attendee parseAttendee(string js) {
		return parseAttendee( JSON.createParser(js) );
	}
		
	public Eventbrite.Event parseEvent(JSONParser jp) {
		Eventbrite.Event ev = new Eventbrite.Event();		
	    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_OBJECT) {
	        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
	            String fn = jp.getText();
	            jp.nextToken();
	            if (jp.getCurrentToken() != JSONToken.VALUE_NULL && jp.getText() != '') {
		            if (fn == 'id') {
		            	ev.id = string.valueOf(jp.getLongValue());
		            } else if (fn == 'title') {
		            	ev.title = jp.getText();
		            } else if (fn == 'description') {
		            	ev.description = jp.getText();
		            } else if (fn == 'category') {
		            	ev.category = jp.getText();
		            } else if (fn == 'tags') {
		            	ev.tags = jp.getText();
		            } else if (fn == 'start_date') {
		            	ev.start_date = datetime.valueOfGmt(jp.getText());
		            } else if (fn == 'end_date') {
		            	ev.end_date = datetime.valueOfGmt(jp.getText());
		            } else if (fn == 'created') {
		            	ev.created = datetime.valueOfGmt(jp.getText());
		            } else if (fn == 'modified') {
		            	ev.modified = datetime.valueOfGmt(jp.getText());
		            } else if (fn == 'timezone') {
		            	ev.timezone = jp.getText();
		            } else if (fn == 'privacy') {
		            	ev.privacy = jp.getText();
		            } else if (fn == 'password') {
		            	ev.password = jp.getText();
		            } else if (fn == 'capacity') {
		            	ev.capacity = jp.getIntegerValue();
		            } else if (fn == 'num_attendee_rows') {  
		            	ev.num_attendee_rows = jp.getIntegerValue();
		            } else if (fn == 'repeats') {
		            	ev.repeats = jp.getText();
		            } else if (fn == 'status') {
		            	ev.status = jp.getText();
		            } else if (fn == 'url') {
		            	ev.url = jp.getText();
		            } else if (fn == 'logo') {
		            	ev.logo = jp.getText();
		            } else if (fn == 'logo_ssl') {
		            	ev.logo_ssl = jp.getText();
		            } else if (fn == 'background_color') {
		            	ev.background_color = jp.getText();
		            } else if (fn == 'text_color') {
		            	ev.text_color = jp.getText();
		            } else if (fn == 'link_color') {
		            	ev.link_color = jp.getText();
		            } else if (fn == 'title_text_color') {
		            	ev.title_text_color = jp.getText();
		            } else if (fn == 'box_background_color') {
		            	ev.box_background_color = jp.getText();
		            } else if (fn == 'box_text_color') {
		            	ev.box_text_color = jp.getText();
		            } else if (fn == 'box_border_color') {
		            	ev.box_border_color = jp.getText();
		            } else if (fn == 'box_header_background_color') {
		            	ev.box_header_background_color = jp.getText();
		            } else if (fn == 'box_header_text_color') {
		            	ev.box_header_text_color = jp.getText();
		            } else if (fn == 'venue') {
					    ev.venue = parseVenue(jp);
		            } else if (fn == 'organizer') {
					    ev.organizer = parseOrganizer(jp);
		            } else if (fn == 'tickets') {
					    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_ARRAY) {
					        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
					            String tfn = jp.getText();
					            jp.nextToken();
					            if (tfn == 'ticket') {
					            	if (ev.tickets == null) 
					            		ev.tickets = new list<Eventbrite.Ticket>();
					                ev.tickets.add( parseTicket(jp) );
					            } else {
									ignoreBadProperty( jp, tfn );
					            }
					        }
					    }		
		            } else {
						ignoreBadProperty( jp, fn );
		            }
	            }
	        }
	    }						
		return ev;
	}

	public Eventbrite.Ticket parseTicket(JSONParser jp) {
		Eventbrite.Ticket tkt = new Eventbrite.Ticket();		
	    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_OBJECT) {
	        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
	            String fn = jp.getText();
	            jp.nextToken();
	            if (jp.getCurrentToken() != JSONToken.VALUE_NULL && jp.getText() != '') {
		            if (fn == 'id') {
		            	tkt.id = string.valueOf(jp.getLongValue());
		            } else if (fn == 'name') {
		            	tkt.name = jp.getText();
		            } else if (fn == 'description') {
		            	tkt.description = jp.getText();
		            } else if (fn == 'type') {
		            	tkt.type = jp.getIntegerValue();
		            } else if (fn == 'price') {
		            	tkt.price = jp.getDecimalValue();
		            } else if (fn == 'currency') {
		            	tkt.currency_code = jp.getText();
		            } else if (fn == 'max') {
		            	tkt.max = jp.getIntegerValue();
		            } else if (fn == 'min') {
		            	tkt.min = jp.getIntegerValue();
		            } else if (fn == 'start_date') {
		            	tkt.start_date = datetime.valueOfGmt(jp.getText());
		            } else if (fn == 'end_date') {
		            	tkt.end_date = datetime.valueOfGmt(jp.getText());
		            } else if (fn == 'quantity_available') {
		            	tkt.quantity_available = jp.getIntegerValue();
		            } else if (fn == 'quantity_sold') {
		            	tkt.quantity_sold = jp.getIntegerValue();
		            } else if (fn == 'visible') {
		            	tkt.visible = (jp.getText() == 'true');
		            } else {
						ignoreBadProperty( jp, fn );
		            }
	            }
	        }
	    }						
		return tkt;
	}
	
	public Eventbrite.Organizer parseOrganizer(JSONParser jp) {
		Eventbrite.Organizer org = new Eventbrite.Organizer();		
	    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_OBJECT) {
	        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
	            String fn = jp.getText();
	            jp.nextToken();
	            if (jp.getCurrentToken() != JSONToken.VALUE_NULL && jp.getText() != '') {
		            if (fn == 'id') {
		            	org.id = string.valueOf(jp.getLongValue());
		            } else if (fn == 'name') {
		            	org.name = jp.getText();
		            } else if (fn == 'description') {
		            	org.description = jp.getText();
		            } else if (fn == 'url') {
		            	org.url = jp.getText();
		            } else {
						ignoreBadProperty( jp, fn );
		            }
	            }
	        }
	    }						
		return org;
	}

	public Eventbrite.Venue parseVenue(JSONParser jp) {
		Eventbrite.Venue vnu = new Eventbrite.Venue();		
	    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_OBJECT) {
	        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
	            String fn = jp.getText();
	            jp.nextToken();
	            if (jp.getCurrentToken() != JSONToken.VALUE_NULL && jp.getText() != '') {
		            if (fn == 'id') {
		            	vnu.id = string.valueOf(jp.getLongValue());
		            } else if (fn == 'name') {
		            	vnu.name = jp.getText();
		            } else if (fn == 'address') {
		            	if (vnu.location == null) vnu.location = new Eventbrite.Address();
		            	vnu.location.address = (vnu.location.address != null) ? (jp.getText() + '\n' + vnu.location.address) : jp.getText();
		            } else if (fn == 'address_2') {
		            	if (vnu.location == null) vnu.location = new Eventbrite.Address();
		            	vnu.location.address = (vnu.location.address != null) ? (vnu.location.address + '\n' +  jp.getText()) : jp.getText();
		            } else if (fn == 'city') {
		            	if (vnu.location == null) vnu.location = new Eventbrite.Address();
		            	vnu.location.city = jp.getText();
		            } else if (fn == 'region') {
		            	if (vnu.location == null) vnu.location = new Eventbrite.Address();
		            	vnu.location.region = jp.getText();
		            } else if (fn == 'postal_code') {
		            	if (vnu.location == null) vnu.location = new Eventbrite.Address();
		            	vnu.location.postal_code = jp.getText();
		            } else if (fn == 'country') {
		            	if (vnu.location == null) vnu.location = new Eventbrite.Address();
		            	vnu.location.country = jp.getText();
		            } else if (fn == 'country_code') {
		            	if (vnu.location == null) vnu.location = new Eventbrite.Address();
		            	vnu.location.country_code = jp.getText();
		            } else if (fn == 'Lat-Long') {
		            	vnu.lat_long = jp.getText();
		            } else if (fn == 'longitude') {
		            	vnu.longitude = jp.getDecimalValue();
		            } else if (fn == 'latitude') {
		            	vnu.latitude = jp.getDecimalValue();
		            } else {
						ignoreBadProperty( jp, fn );
		            }
	            }
	        }
	    }						
		return vnu;
	}

	public Eventbrite.Answer parseAnswer(JSONParser jp) {
		Eventbrite.Answer ans = new Eventbrite.Answer();
	    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_OBJECT) {
	        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
	            String fn = jp.getText();
	            jp.nextToken();
	            if (jp.getCurrentToken() != JSONToken.VALUE_NULL && jp.getText() != '') {
		            if (fn == 'question_id') {
		            	ans.question_id = string.valueOf(jp.getLongValue());
		            } else if (fn == 'question') {
		            	ans.question = jp.getText();
		            } else if (fn == 'question_type') {
		            	ans.question_type = jp.getText();
		            } else if (fn == 'answer_text') {
		            	ans.answer_text = jp.getText();
		            } else {
						ignoreBadProperty( jp, fn );
		            }
	            }
	        }
	    }						
		return ans;
	}
	
	public Eventbrite.Barcode parseBarcode(JSONParser jp) {
		Eventbrite.Barcode bc = new Eventbrite.Barcode();
	    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_OBJECT) {
	        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
	            String fn = jp.getText();
	            jp.nextToken();
	            if (jp.getCurrentToken() != JSONToken.VALUE_NULL && jp.getText() != '') {
		            if (fn == 'id') {
		            	bc.id = jp.getText();
		            } else if (fn == 'attendee_id') {
		            	bc.attendee_id = string.valueOf(jp.getLongValue());
		            } else if (fn == 'status') {
		            	bc.status = jp.getText();
		            } else if (fn == 'checkin_type') {
		            	bc.checkin_type = jp.getIntegerValue();
		            } else if (fn == 'checkin_method') {
		            	bc.checkin_method = jp.getText();
		            } else if (fn == 'device_id') {
		            	bc.device_id = jp.getText();
		            } else if (fn == 'date_created') {
		            	bc.date_created = datetime.valueOfGmt(jp.getText());
		            } else if (fn == 'date_modified') {
		            	bc.date_modified = datetime.valueOfGmt(jp.getText());
		            } else {
						ignoreBadProperty( jp, fn );
		            }
	            }
	        }
	    }						
		return bc;
	}
	
	public Eventbrite.Attendee parseAttendee(JSONParser jp) {
		Eventbrite.Attendee atd = new Eventbrite.Attendee();		
	    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_OBJECT) {
	        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
	            String fn = jp.getText();
	            jp.nextToken();
	            if (jp.getCurrentToken() != JSONToken.VALUE_NULL && jp.getText() != '') {
		            if (fn == 'id') {
		            	atd.id = string.valueOf(jp.getLongValue());
		            } else if (fn == 'event_id') {
		            	atd.event_id = string.valueOf(jp.getLongValue());
		            } else if (fn == 'ticket_id') {
		            	atd.ticket_id = string.valueOf(jp.getLongValue());
		            } else if (fn == 'quantity') {
		            	atd.quantity = jp.getIntegerValue();
		            } else if (fn == 'currency') {
		            	atd.currency_code = jp.getText();
		            } else if (fn == 'amount_paid') {
		            	try {
		            		atd.amount_paid = decimal.valueOf(jp.getText());
		            	} catch (exception e) {}
		            } else if (fn == 'barcode') {
		            	atd.barcode = jp.getText().split(',');
		            } else if (fn == 'order_id') {
		            	atd.order_id = string.valueOf(jp.getLongValue());
		            } else if (fn == 'order_type') {
		            	atd.order_type = jp.getText();
		            } else if (fn == 'event_date') {
		            	atd.event_date = datetime.valueOfGmt(jp.getText());
		            } else if (fn == 'created') {
		            	atd.created = datetime.valueOfGmt(jp.getText());
		            } else if (fn == 'modified') {
		            	atd.modified = datetime.valueOfGmt(jp.getText());
		            } else if (fn == 'discount') {
		            	atd.discount = jp.getText();
		            } else if (fn == 'notes') {
		            	atd.notes = jp.getText();
		            } else if (fn == 'affiliate') {
		            	atd.notes = jp.getText();
		            } else if (fn == 'email') {
		            	atd.email = jp.getText();
		            } else if (fn == 'prefix') {
		            	atd.prefix = jp.getText();
		            } else if (fn == 'first_name') {
		            	atd.first_name = jp.getText();
		            } else if (fn == 'last_name') {
		            	atd.last_name = jp.getText();
		            } else if (fn == 'suffix') {
		            	atd.suffix = jp.getText();
		            } else if (fn == 'home_phone') {
		            	atd.home_phone = jp.getText();
		            } else if (fn == 'cell_phone') {
		            	atd.cell_phone = jp.getText();
		            } else if (fn == 'work_phone') {
		            	atd.work_phone = jp.getText();
		            } else if (fn == 'company') {
		            	atd.company = jp.getText();
		            } else if (fn == 'job_title') {
		            	atd.job_title = jp.getText();
		            } else if (fn == 'website') {
		            	atd.website = jp.getText();
		            } else if (fn == 'blog') {
		            	atd.blog = jp.getText();
		            } else if (fn == 'gender') {
		            	atd.gender = jp.getText();
		            } else if (fn == 'birth_date') {
		            	atd.birth_date = date.valueOf(jp.getText());
		            } else if (fn == 'age') {
		            	atd.age = jp.getIntegerValue();
		            } else if (fn == 'home_address') {
		            	if (atd.home_address == null) atd.home_address = new Eventbrite.Address();
		            	atd.home_address.address = (atd.home_address.address != null) ? (jp.getText() + '\n' + atd.home_address.address) : jp.getText();
		            } else if (fn == 'home_address_2') {
		            	if (atd.home_address == null) atd.home_address = new Eventbrite.Address();
		            	atd.home_address.address = (atd.home_address.address != null) ? (atd.home_address.address + '\n' +  jp.getText()) : jp.getText();
		            } else if (fn == 'home_city') {
		            	if (atd.home_address == null) atd.home_address = new Eventbrite.Address();
		            	atd.home_address.city = jp.getText();
		            } else if (fn == 'home_region') {
		            	if (atd.home_address == null) atd.home_address = new Eventbrite.Address();
		            	atd.home_address.region = jp.getText();
		            } else if (fn == 'home_postal_code') {
		            	if (atd.home_address == null) atd.home_address = new Eventbrite.Address();
		            	atd.home_address.postal_code = jp.getText();
		            } else if (fn == 'home_country') {
		            	if (atd.home_address == null) atd.home_address = new Eventbrite.Address();
		            	atd.home_address.country = jp.getText();
		            } else if (fn == 'home_country_code') {
		            	if (atd.home_address == null) atd.home_address = new Eventbrite.Address();
		            	atd.home_address.country_code = jp.getText();
		            } else if (fn == 'work_address') {
		            	if (atd.work_address == null) atd.work_address = new Eventbrite.Address();
		            	atd.work_address.address = (atd.work_address.address != null) ? (jp.getText() + '\n' + atd.work_address.address) : jp.getText();
		            } else if (fn == 'work_address_2') {
		            	if (atd.work_address == null) atd.work_address = new Eventbrite.Address();
		            	atd.work_address.address = (atd.work_address.address != null) ? (atd.work_address.address + '\n' +  jp.getText()) : jp.getText();
		            } else if (fn == 'work_city') {
		            	if (atd.work_address == null) atd.work_address = new Eventbrite.Address();
		            	atd.work_address.city = jp.getText();
		            } else if (fn == 'work_region') {
		            	if (atd.work_address == null) atd.work_address = new Eventbrite.Address();
		            	atd.work_address.region = jp.getText();
		            } else if (fn == 'work_postal_code') {
		            	if (atd.work_address == null) atd.work_address = new Eventbrite.Address();
		            	atd.work_address.postal_code = jp.getText();
		            } else if (fn == 'work_country') {
		            	if (atd.work_address == null) atd.work_address = new Eventbrite.Address();
		            	atd.work_address.country = jp.getText();
		            } else if (fn == 'work_country_code') {
		            	if (atd.work_address == null) atd.work_address = new Eventbrite.Address();
		            	atd.work_address.country_code = jp.getText();
		            } else if (fn == 'ship_address') {
		            	if (atd.ship_address == null) atd.ship_address = new Eventbrite.Address();
		            	atd.ship_address.address = (atd.ship_address.address != null) ? (jp.getText() + '\n' + atd.ship_address.address) : jp.getText();
		            } else if (fn == 'ship_address_2') {
		            	if (atd.ship_address == null) atd.ship_address = new Eventbrite.Address();
		            	atd.ship_address.address = (atd.ship_address.address != null) ? (atd.ship_address.address + '\n' +  jp.getText()) : jp.getText();
		            } else if (fn == 'ship_city') {
		            	if (atd.ship_address == null) atd.ship_address = new Eventbrite.Address();
		            	atd.ship_address.city = jp.getText();
		            } else if (fn == 'ship_region') {
		            	if (atd.ship_address == null) atd.ship_address = new Eventbrite.Address();
		            	atd.ship_address.region = jp.getText();
		            } else if (fn == 'ship_postal_code') {
		            	if (atd.ship_address == null) atd.ship_address = new Eventbrite.Address();
		            	atd.ship_address.postal_code = jp.getText();
		            } else if (fn == 'ship_country') {
		            	if (atd.ship_address == null) atd.ship_address = new Eventbrite.Address();
		            	atd.ship_address.country = jp.getText();
		            } else if (fn == 'ship_country_code') {
		            	if (atd.ship_address == null) atd.ship_address = new Eventbrite.Address();
		            	atd.ship_address.country_code = jp.getText();
		            } else if (fn == 'answers') {
					    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_ARRAY) {
					        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
					            String afn = jp.getText();
					            jp.nextToken();
					            if (afn == 'answer') {
					            	if (atd.answers == null) 
					            		atd.answers = new list<Eventbrite.Answer>();
					                atd.answers.add( parseAnswer(jp) );
					            } else {
									ignoreBadProperty( jp, afn );
					            }
					        }
					    }		
		            } else if (fn == 'barcodes') {
					    while (jp.nextToken() != null && jp.getCurrentToken() != JSONToken.END_ARRAY) {
					        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
					            String afn = jp.getText();
					            jp.nextToken();
					            if (afn == 'barcode') {
					            	if (atd.barcodes == null) 
					            		atd.barcodes = new list<Eventbrite.Barcode>();
					                atd.barcodes.add( parseBarcode(jp) );
					            } else {
									ignoreBadProperty( jp, afn );
					            }
					        }
					    }		
		            } else {
						ignoreBadProperty( jp, fn );
		            }
	            }
	        }
	    }						
		return atd;
	}
	
	private void ignoreBadProperty( JSONParser jp, string badPropertyName ) {
        System.debug(LoggingLevel.WARN, 'Unrecognized property in json data: ' + badPropertyName);
		jp.skipChildren();
	}

	public class EventbriteException extends Exception {
		// eventbrite returns this in addition to a message - e.g. Authentication Error
		public string errorType { get; private set; }
		
		public EventbriteException(JSONParser jp) {
		    while (jp.nextToken() != null) {
		        if (jp.getCurrentToken() == JSONToken.FIELD_NAME) {
		            String fn = jp.getText();
		            jp.nextToken();
		            if (fn == 'error_type') {
		            	errorType = jp.getText();
		            } else if (fn == 'error_message') {
		                this.setMessage( jp.getText() );
		            } else {
				        System.debug(LoggingLevel.WARN, 'Unrecognized property in json data: ' + fn);
						jp.skipChildren();
		            }
		        }
		    }					
		}
	}

	static testmethod void testEBdata() {

		Eventbrite eb;
	
		// actual data you can expect from EB - I put in one bad property
		string userListEventsResponse = '{"events": [{"event": {"box_header_text_color_BOGUS": "005580", "link_color": "EE6600", "box_background_color": "FFFFFF", "timezone": "US/Pacific", "box_border_color": "D5D5D3", "logo": "http://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "organizer": {"url": "http://www.eventbrite.com/org/515399719", "description": "", "id": 2696456173, "name": ""}, "background_color": "FFFFFF", "id": 586701841, "category": "", "box_header_background_color": "EFEFEF", "capacity": 5000, "num_attendee_rows": 5, "title": "Test Free Event", "start_date": "2011-02-16 13:00:00", "status": "Completed", "description": "", "end_date": "2011-02-16 16:00:00", "tags": "", "text_color": "005580", "title_text_color": "", "tickets": [{"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "0.00", "quantity_sold": 7, "visible": "true", "currency": "USD", "quantity_available": 20, "type": 0, "id": 9196395, "name": "Free Ticket"}}, {"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "50.00", "quantity_sold": 0, "visible": "true", "currency": "USD", "quantity_available": 100, "type": 0, "id": 9960065, "name": "Ticket plus Donation"}}], "created": "2010-02-24 10:55:06", "url": "http://www.eventbrite.com/event/586701841", "box_text_color": "000000", "privacy": "Public", "venue": {"city": "Seattle", "name": "Groundwire", "country": "United States", "region": "WA", "longitude": -122.336787, "postal_code": "98101", "address_2": "", "address": "1402 3rd Ave", "latitude": 47.609093000000001, "country_code": "US", "id": 422693, "Lat-Long": "47.609093 / -122.336787"}, "modified": "2011-02-16 20:30:34", "logo_ssl": "https://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "repeats": "no"}}, {"event": {"box_header_text_color": "FFFFFF", "link_color": "C27B13", "box_background_color": "FFFFFF", "box_border_color": "C27B13", "timezone": "US/Pacific", "organizer": {"url": "http://www.eventbrite.com/org/581998671", "description": "", "id": 581998671, "name": ""}, "background_color": "FFFFFF", "id": 578263602, "category": "", "box_header_background_color": "5E9732", "capacity": 10, "num_attendee_rows": 3, "title": "Test Event - Happy Hour with Evan", "start_date": "2010-10-21 16:30:00", "status": "Completed", "description": "", "end_date": "2010-10-22 17:15:00", "tags": "", "text_color": "54301A", "title_text_color": "", "password": "", "tickets": [{"ticket": {"description": "", "end_date": "2010-10-21 13:30:00", "min": 0, "max": 0, "price": "0.00", "quantity_sold": 4, "visible": "true", "currency": "USD", "quantity_available": 10, "type": 0, "id": 8927061, "name": "Free"}}, {"ticket": {"description": "This is a special ticket for adults.", "end_date": "2010-10-21 13:30:00", "min": 0, "max": 0, "price": "0.00", "quantity_sold": 0, "visible": "true", "currency": "USD", "quantity_available": 2, "type": 0, "id": 9121166, "name": "Adult"}}, {"ticket": {"description": "", "end_date": "2010-10-21 13:30:00", "min": 0, "max": 0, "quantity_sold": 0, "visible": "true", "currency": "USD", "quantity_available": 10, "type": 1, "id": 9464865, "name": "Registration with Addition Donation (minimum $30 per person)"}}], "created": "2010-02-17 16:27:58", "url": "http://happyhourwithevan.eventbrite.com", "box_text_color": "000000", "privacy": "Private", "venue": {"city": "Seattle", "name": "", "country": "United States", "region": "", "longitude": -122.337318, "postal_code": "", "address_2": "", "address": "216 Union", "latitude": 47.608662000000002, "country_code": "US", "id": 450036, "Lat-Long": "47.608662 / -122.337318"}, "modified": "2011-11-02 11:54:35", "repeats": "no"}}]}';
		string oneEvent = '{"box_header_text_color_BOGUS": "005580", "link_color": "EE6600", "box_background_color": "FFFFFF", "timezone": "US/Pacific", "box_border_color": "D5D5D3", "logo": "http://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "organizer": {"url": "http://www.eventbrite.com/org/515399719", "description": "", "id": 515399719, "name": ""}, "background_color": "FFFFFF", "id": 586701841, "category": "", "box_header_background_color": "EFEFEF", "capacity": 5000, "num_attendee_rows": 5, "title": "Test Free Event", "start_date": "2011-02-16 13:00:00", "status": "Completed", "description": "", "end_date": "2011-02-16 16:00:00", "tags": "", "text_color": "005580", "title_text_color": "", "tickets": [{"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "0.00", "quantity_sold": 7, "visible": "true", "currency": "USD", "quantity_available": 20, "type": 0, "id": 9196395, "name": "Free Ticket"}}, {"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "50.00", "quantity_sold": 0, "visible": "true", "currency": "USD", "quantity_available": 100, "type": 0, "id": 9960065, "name": "Ticket plus Donation"}}], "created": "2010-02-24 10:55:06", "url": "http://www.eventbrite.com/event/586701841", "box_text_color": "000000", "privacy": "Public", "venue": {"city": "Seattle", "name": "Groundwire", "country": "United States", "region": "WA", "longitude": -122.336787, "postal_code": "98101", "address_2": "", "address": "1402 3rd Ave", "latitude": 47.609093000000001, "country_code": "US", "id": 422693, "Lat-Long": "47.609093 / -122.336787"}, "modified": "2011-02-16 20:30:34", "logo_ssl": "https://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "repeats": "no"}';
		string attendeeListResponse = '{"attendees": [{"attendee": {"last_name": "Averill", "home_address": "", "home_postal_code": "98115", "currency": "USD", "id": 17013442, "first_name": "Dave", "order_type": "Free Order", "event_id": 578263602, "home_address_2": "", "ticket_id": 8927061, "home_phone": "", "event_date": "", "email": "", "home_country_code": "US", "home_city": "", "order_id": 12805465, "amount_paid": "0.00", "barcode": "1280546517013442001", "answers": [{"answer": {"answer_text": "Manhattans", "question": "What do you want to drink?", "question_type": "text", "question_id": 474294}}, {"answer": {"answer_text": "Accepted", "question": "Waiver of Liability", "question_type": "text", "question_id": 474295}}], "home_region": "WA", "discount": "", "home_country": "US", "created": "2010-06-16 11:37:51", "modified": "2010-06-16 11:40:12", "affiliate": "etckt", "quantity": 1}}, {"attendee": {"last_name": "CallahanTEST", "home_address": "", "home_postal_code": "", "currency": "USD", "id": 17013441, "first_name": "Evan", "order_type": "Free Order", "event_id": 578263602, "home_address_2": "", "ticket_id": 8927061, "home_phone": "", "event_date": "", "email": "evan@groundwire.org", "home_country_code": "US", "home_city": "", "order_id": 12805465, "amount_paid": "1.23", "barcode": "1280546517013441001", "answers": [{"answer": {"answer_text": "Martinis", "question": "What do you want to drink?", "question_type": "text", "question_id": 474294}}], "home_region": "WA", "discount": "", "home_country": "US", "created": "2010-06-16 11:37:51", "modified": "2010-06-16 11:40:12", "affiliate": "etckt", "quantity": 1}}, {"attendee": {"first_name": "Evan", "last_name": "CallahanTEST", "order_type": "Free Order", "created": "2010-02-17 16:35:11", "order_id": 9442134, "amount_paid": "0.00", "barcode": "0944213412727309001,0944213412727309002", "modified": "2010-02-17 16:35:31", "answers": [], "id": 12727309, "currency": "USD", "affiliate": "", "ticket_id": 8927061, "event_id": 578263602, "event_date": "", "discount": "", "email": "evan@groundwire.org", "quantity": 2, "barcodes": [{"barcode": {"status": "unused", "date_modified": "2011-12-28 15:46:19", "checkin_type": 0, "checkin_method": null, "attendee_id": 80361991, "date_created": "2011-12-28 23:46:19", "id": "6315759380361991001", "device_id": null}}]}}]}';
		string oneAttendee = '{"last_name": "CallahanTEST", "home_address": "", "suffix": "", "home_postal_code": "98115", "currency": "USD", "prefix": "", "id": 17348011, "first_name": "Bob", "order_type": "Free Order", "event_id": 586701841, "home_address_2": "", "blog": "", "ticket_id": 9196395, "home_phone": "", "event_date": "", "email": "evan+bobtest@groundwire.org", "job_title": "", "website": "", "home_country_code": "US", "home_city": "", "order_id": 13070182, "company": "", "barcode": "1307018217348011001,1307018217348011002", "home_region": "WA", "discount": "", "amount_paid": "0.00", "home_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "", "cell_phone": "765.4848x89", "notes": "", "quantity": 2}';
		string errorResponse = '{"error": {"error_type": "Authentication Error", "error_message": "Invalid user_key"}}';
		string bogusJson = 'crud';

		// test the event list		
		eb = new Eventbrite();
		list<Eventbrite.Event> events = eb.parseUserListEvents( userListEventsResponse );
		System.debug(LoggingLevel.WARN, events);
		system.assertEquals(2, events.size());
		system.assertEquals('Seattle', events[0].venue.location.city);
		system.assertEquals(2, events[0].tickets.size());
		
		// test one event		
		eb = new Eventbrite();
		Eventbrite.Event ebEvent = eb.parseEvent( oneEvent );
		System.debug(LoggingLevel.WARN, ebEvent);

		// test the attendee list
		eb = new Eventbrite();
		list<Eventbrite.Attendee> attendees = eb.parseEventListAttendees( attendeeListResponse );
		System.debug(LoggingLevel.WARN, attendees);
		system.assertEquals(3, attendees.size());
		system.assertEquals('98115', attendees[0].home_address.postal_code);
		system.assertEquals(null, attendees[0].work_address);
		system.assertEquals(0, attendees[0].amount_paid);
		system.assertEquals(1.23, attendees[1].amount_paid);
		
		// test one event
		eb = new Eventbrite();
		Eventbrite.Attendee ebPeep = eb.parseAttendee( oneAttendee );
		System.debug(LoggingLevel.WARN, ebPeep);
		system.assertEquals(2, ebPeep.barcode.size());

		// test an error response		
		eb = new Eventbrite();
		string myerr; 
		try {
			events = eb.parseUserListEvents( errorResponse );
		} catch (exception e) {
			myerr = e.getMessage();
		}
		system.assertEquals('Invalid user_key', myerr);

		// test an bogus JSON response		
		eb = new Eventbrite();
		string anothererr;
		try {
			events = eb.parseUserListEvents( bogusJson );
		} catch (exception e) {
			anothererr = e.getMessage();
		}
		system.assert(anothererr.startsWith('Unexpected character'));
	}
}