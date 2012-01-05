public with sharing class EventbriteConnectController {
/*-----------------------------------------------------------------------------------------------
* Visualforce controller class for Eventbrite for Salesforce 
* Written by Evan Callahan

      Copyright (c) 2012, Groundwire Consulting, Inc.
      All rights reserved.

      Redistribution and use in source and binary forms, with or without
      modification, are permitted provided that the following conditions are met:

      * Redistributions of source code must retain the above copyright
         notice, this list of conditions and the following disclaimer.
      * Redistributions in binary form must reproduce the above copyright
         notice, this list of conditions and the following disclaimer in the
         documentation and/or other materials provided with the distribution.
      * Neither the name of Groundwire Consulting, Inc. nor the names of
         its contributors may be used to endorse or promote products derived
         from this software without specific prior written permission.

      THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
      "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
      LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
      FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
      COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
      INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
      BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
      LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
      CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
      LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
      ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
      POSSIBILITY OF SUCH DAMAGE.
      
*-----------------------------------------------------------------------------------------------*/
	
	public string settingsJson { get; private set; }
	public string campaignJson { get; private set; }
	public campaign targetCampaign { get; set; }
	public opportunity defaultOpp { get; set; }
	public opportunityContactRole defaultOCR { get; set; }
	public list<selectOption> CampaignRecordTypes { get; private set; }
	public list<selectOption> OppRecordTypes { get; private set; }

	public string accountLabelPlural { get; private set; }
	public string contactLabel { get; private set; }
	public string contactLabelPlural { get; private set; }
	public string leadLabel { get; private set; }
	public string leadLabelPlural { get; private set; }
	public string campaignLabel { get; private set; }
	public string oppLabel { get; private set; }
	public string oppLabelPlural { get; private set; }
	public string mailingAddressLabel { get; private set; }
	public string otherAddressLabel { get; private set; }

	public static Schema.DescribeSObjectResult oppDesc;
	public static Map<String,Schema.RecordTypeInfo> oppRecordTypesByName;
	public static Schema.DescribeSObjectResult campaignDesc;
	public static Map<String,Schema.RecordTypeInfo> campaignRecordTypesByName;
	
	public EventbriteConnectController() {
		// get record types
		Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
		oppDesc = gd.get('Opportunity').getDescribe();
		oppRecordTypesByName = oppDesc.getRecordTypeInfosByName();
		if (oppRecordTypesByName.size() > 1) { 
			OppRecordTypes = new list<selectOption>();
			for (string s : oppRecordTypesByName.keyset()) {
				recordTypeInfo rt = oppRecordTypesByName.get(s);
				if (rt.isAvailable() && s != 'Master')
					OppRecordTypes.add(new selectOption(rt.getRecordTypeId(), rt.getName()));
			}
		}
		campaignDesc = gd.get('Campaign').getDescribe();
		campaignRecordTypesByName = campaignDesc.getRecordTypeInfosByName();
		if (campaignRecordTypesByName.size() > 1) { 
			campaignRecordTypes = new list<selectOption>();
			for (string s : campaignRecordTypesByName.keyset()) {
				recordTypeInfo rt = campaignRecordTypesByName.get(s);
				if (rt.isAvailable() && s != 'Master')
					campaignRecordTypes.add(new selectOption(rt.getRecordTypeId(), rt.getName()));
			}
		}
		accountLabelPlural = Describe.getObjectLabelPlural('Account');
		contactLabel = Describe.getObjectLabel('Contact');
		contactLabelPlural = Describe.getObjectLabelPlural('Contact');
		leadLabel = Describe.getObjectLabel('Lead');
		leadLabelPlural = Describe.getObjectLabelPlural('Lead');
		campaignLabel = Describe.getObjectLabel('Campaign');
		oppLabel = Describe.getObjectLabel('Opportunity');
		oppLabelPlural = Describe.getObjectLabelPlural('Opportunity');
		mailingAddressLabel = Describe.getFieldLabel('Contact', 'MailingStreet').replace('Street', 'Address');
		otherAddressLabel = Describe.getFieldLabel('Contact', 'OtherStreet').replace('Street', 'Address');

		// get settings
		settingsJson = JSON.serializePretty(
			Eventbrite_Connector_Settings__c.getInstance( UserInfo.getUserId() )
		);
		
		targetCampaign = new Campaign();
		defaultOpp = new Opportunity();
		defaultOCR = new OpportunityContactRole();
				
	}
	
	@RemoteAction
	public static list<campaign> getCampaignList( integer maxRecords ) {
		return [select id, name, startdate, lastmodifieddate, type, status, isactive
				from campaign order by lastmodifieddate desc limit : maxRecords];
	}
	
	public class CreateCampaignResult {
		public string campaignId;
		public list<string> campaignMemberStatuses;
	}
	
	@RemoteAction
	public static CreateCampaignResult createCampaign( string campaignName, string recordType, 
		string campaignType, date startDate, date endDate, string status, string parentCampaignId ) {
		
		CreateCampaignResult ccr = new CreateCampaignResult();
		
		id rectypeid;
		if (campaignRecordTypesByName != null && campaignRecordTypesByName.containsKey(recordType))
			rectypeid = campaignRecordTypesByName.get(recordType).getRecordTypeId();
			
		campaign c = new Campaign( 
			name = campaignName, 
			type = campaignType, 
			startdate = startdate,
			enddate = enddate,
			parentId = parentCampaignId,
			status = status,
			isActive = true
		);
		if (rectypeid != null)
			c.put('recordTypeId', rectypeid);
			
		insert c;
		ccr.campaignId = c.id;
		
		ccr.campaignMemberStatuses = new list<string>();
		
		for (campaignMemberStatus cm : [select Label from CampaignMemberStatus 
			where campaignId =: c.id order by SortOrder]) { 
			
			ccr.campaignMemberStatuses.add(cm.Label);
		}
		
		return ccr;
	}

	public class ImportAttendeeResult {
		string summary;
		string firstname;
		string lastname;
		string link;
		string opportunityName;
		string opportunityLink;
		string errorMessage;		
	} 

	// remote method that the connector page calls to do the import
	@RemoteAction
	public static list<ImportAttendeeResult> importAttendees(
		string eventJson, list<string> attendeeJson, string settingsJson, 
		string campaignId, string contactDescription) {

		// deserialize settings
		JSONParser parser = JSON.createParser( settingsJson );
		Eventbrite_Connector_Settings__c settings = (Eventbrite_Connector_Settings__c)parser.readValueAs(Eventbrite_Connector_Settings__c.class);

		// not working with managed package		
		//Type classType = Type.forName('Eventbrite_Connector_Settings__c'); 
		//Eventbrite_Connector_Settings__c settings = (Eventbrite_Connector_Settings__c)parser.readValueAs(classType);
		
		// get the set of contact emails and order Ids in the attendee list
		set<string> attendeeEmails = new set<string>();
		set<string> orderIds = new set<string>();
		map<string, Eventbrite.Attendee> companyNameMap = new map<string, Eventbrite.Attendee>();
		map<string, string> ticketNameMap = new map<string, string>(); 

		// parse json
		Eventbrite eb = new Eventbrite();
		Eventbrite.Event ebEvent = eb.parseEvent( eventJson );
		
		// get ticket type names
		for (Eventbrite.Ticket tkt : ebEvent.tickets) {
			ticketNameMap.put(tkt.id, tkt.name);
		}
		
		// parse attendee records
		list<Eventbrite.Attendee> ebaList = new list<Eventbrite.Attendee>();
		for (string js : attendeeJson) {
			Eventbrite.Attendee eba = eb.parseAttendee(js);
			ebaList.add(eba);
			if (settings.use_existing_contact__c && eba.email != null) 
				attendeeEmails.add( eba.email );
			if (eba.order_id != null)
				orderIds.add( eba.order_id );
			if (eba.company != null) 
				companyNameMap.put( eba.company, eba );
		}

		// get the field names
		set<string> contactFieldNames = Describe.getAllFieldNames('Contact');
		set<string> leadFieldNames;
		set<string> oppFieldNames;
		if (settings.Option_for_Leads_or_Contacts__c == 0) 
			leadFieldNames = Describe.getAllFieldNames('Lead');
		else if (settings.Option_for_Leads_or_Contacts__c == 2) 
			oppFieldNames = Describe.getAllFieldNames('Opportunity');					

		// query for matches - map emails to matched contacts
		map<id, contact> contactIdMatchMap = new map<id, contact>();
		map<string, contact> contactMatchMap = new map<string, contact>();
		set<id> contactMatches = new set<id>();
		string otherEmail;
		if (settings.use_existing_contact__c) {

			// for gwbase we want to check secondary email too
			if (contactFieldNames.contains('GWBase__Secondary_Email__c'))
				otherEmail = 'GWBase__Secondary_Email__c';
			else if (contactFieldNames.contains('Secondary_Email__c')) 
				otherEmail = 'Secondary_Email__c';

			string matchQuery = 'select id, name, firstname, lastname, title, email, mailingStreet, otherStreet, salutation, birthdate, mobilePhone, phone, homephone  ';
			if (otherEmail != null)
				matchQuery += ',' + otherEmail + ' ';
			matchQuery += 'from contact where email in :attendeeEmails ';			
			if (otherEmail != null)
				matchQuery += 'or ' + otherEmail + ' in :attendeeEmails ';
			matchQuery += 'order by lastModifiedDate';

			for (contact c : database.query(matchQuery)) {
				contactIdMatchMap.put(c.id, c);
				if (attendeeEmails.contains(c.email)) {
					contactMatchMap.put(c.email, c);
					contactMatches.add(c.id);
				} else if (otherEmail != null && !contactMatchMap.containsKey((string)(c.get(otherEmail)))) {
					contactMatchMap.put((string)(c.get(otherEmail)), c);
					contactMatches.add(c.id);
				}
			}
		}
		
		// map the existing account names
		map<string, id> accountNameMap = new map<string, id>(); 
		if (settings.Option_for_Leads_or_Contacts__c != 0) {
			for (account a : [select id, name from account where name in : companyNameMap.keyset() order by lastModifiedDate])
				accountNameMap.put(a.name, a.id);

			if (settings.create_accounts__c) {
				list<account> newAccts = new list<account>();
				for (string s: companyNameMap.keyset()) {
					if (!accountNameMap.containsKey(s)) {
						Eventbrite.Attendee eba = companyNameMap.get(s);
						account a = new Account(name = s, description = contactDescription, website = eba.website);
						fillAddress(eba.work_address, (sobject)a, 'billing', false);
						newAccts.add(a);
					}
				}
				if (!newAccts.isEmpty()) {
					insert newAccts;
					for (account a : newAccts)
						accountNameMap.put(a.name, a.id);
				}
			}
		}

		// map the existing campaign members from the affected campaign by contactid or leadid
		map<id, CampaignMember> memberMap = new map<id, CampaignMember>(); 
		if (campaignId != null) {
			for (campaignMember cm : 
				[select id, campaignId, leadId, contactId, status, eventbrite_barcodes__c, Eventbrite_Checkins__c, 
					eventbrite_ticket_type__c, eventbrite_ticket_quantity__c from campaignMember 
					where campaignId = : campaignId and contactId in : contactMatches]) {
						
				memberMap.put((cm.contactId == null) ? cm.leadId : cm.contactId, cm);
			}
			
			// update the campaign with this eventbrite id
			campaign cmp = new campaign(id = campaignId, eventbrite_event_id__c = ebEvent.id);
			update cmp;
		}
		
		// map the existing order opps
		map<string, Opportunity> orderOppMap = new map<string, Opportunity>(); 
		if (settings.Option_for_Leads_or_Contacts__c == 2) {
			for (opportunity o : [select id, amount, name, stagename, closedate, campaignId, eventbrite_order_id__c,
					Eventbrite_Answers__c, Eventbrite_Attendee_IDs__c, Eventbrite_Ticket_Quantity__c, Eventbrite_Ticket_Type__c 
					from opportunity where Eventbrite_Order_Id__c in : orderIds])
				orderOppMap.put(o.eventbrite_order_id__c, o);
		}

		// get the rectype id for new opps
		id oppRecTypeId;
		if (settings.Opp_Record_Type_Name__c != null && settings.Option_for_Leads_or_Contacts__c == 2 && 
			oppRecordTypesByName.size() > 1 && oppRecordTypesByName.containsKey(settings.Opp_Record_Type_Name__c)) { 
			
			recordTypeInfo rt = oppRecordTypesByName.get(settings.Opp_Record_Type_Name__c);
			if (rt.isAvailable())
				oppRecTypeId = rt.getRecordTypeId();
		}
		
		// create lists for later update or insert
		list<lead> leadsToInsert = new list<lead>();
		list<contact> contactsToUpsert = new list<contact>();

		// for each DML list, need to track the indexes of the records we are sending
		// so we can always match results back to the right attendee record 
		list<integer> leadInsertIndexes = new list<integer>();
		list<integer> contactUpsertIndexes = new list<integer>();

		// use an id set to make sure we don't duplicate contacts
		set<id> conSet = new set<id>();
		
		// are these still required?
		map<integer, lead> indexLeadMap = new map<integer, lead>();
		map<integer, contact> indexContactMap = new map<integer, contact>();
		
		string otherAddressLabel = Describe.getFieldLabel('Contact', 'OtherStreet').replace('Street', 'Address');
		
		for (integer i = 0; i < ebaList.size(); i++) {		
			Eventbrite.Attendee eba = ebaList[i]; 
			
			if (settings.Option_for_Leads_or_Contacts__c == 0 && 
				(!settings.Use_Existing_Contact__c || !contactMatchMap.containsKey(eba.email))) {

				// create a lead
				lead l = new lead(
					salutation = eba.prefix,
					firstName = eba.first_name,
					lastName = eba.last_name,
					company = (eba.company == null) ? '[not provided]' : eba.company,
					email = eba.email,
					phone = eba.work_phone,
					mobilePhone = eba.cell_phone,
					title = eba.job_title,
					description = contactDescription
				);
				leadInsertIndexes.add(i);
				leadsToInsert.add(l);
				indexLeadMap.put(i, l);
								
				if (leadFieldNames.contains('GWBase__Home_Phone__c')) {
					l.put('GWBase__Home_Phone__c', eba.home_phone);
					l.put('GWBase__Home_Street__c', eba.home_address.address);
					l.put('GWBase__Home_City__c', eba.home_address.city);
					l.put('GWBase__Home_State__c', eba.home_address.region);
					l.put('GWBase__Home_PostalCode__c', eba.home_address.postal_code);
					l.put('GWBase__Home_Country__c', eba.home_address.country);
					l.put('GWBase__Opportunity_Amount__c', eba.amount_paid);
					l.put('GWBase__Opportunity_Date__c', eba.created.date());
					l.put('GWBase__Opportunity_Description__c', 'Eventbrite Order - ' + ebEvent.title);
					l.put('GWBase__Opportunity_Record_Type__c', oppRecTypeId);
					l.put('GWBase__Opportunity_Stage__c', settings.opp_stage__c);
				
				} else if (leadFieldNames.contains('Home_Phone__c')) {
					l.put('Home_Phone__c', eba.home_phone);
				} else if (eba.work_phone == null) {
					l.phone = eba.home_phone;
				}

				if (eba.work_address != null) {
					fillAddress(eba.work_address, (sobject)l, null, false);				
				} else if (eba.home_address != null && !leadFieldNames.contains('GWBase__Home_Phone__c')) {
					fillAddress(eba.home_address, (sobject)l, null, false);
				}
				
			} else {
				
				// create or update a contact
				contact c;
				if (contactMatchMap.containsKey(eba.email)) { 
					c = contactMatchMap.get(eba.email);

					if (c.id != null && !conSet.contains(c.id)) {
						contactUpsertIndexes.add(i);						
						contactsToUpsert.add(c);
						conSet.add(c.id);
					}
					
				} else {

					c = new Contact(
						firstName = eba.first_name,
						lastName = eba.last_name,
						email = eba.email,
						description = contactDescription,
						accountid = accountNameMap.get(eba.company)
					);
					contactUpsertIndexes.add(i);
					contactsToUpsert.add(c);
				
					// use this one again for this same email
					contactMatchMap.put(eba.email, c);
				}
				indexContactMap.put(i, c);

				boolean overwrite = settings.Overwrite_Contact_Detail__c;

				if (eba.work_address != null && c.MailingStreet == null)
					fillAddress(eba.work_address, (sobject)c, 'Mailing', overwrite);
				
				if (eba.home_address != null) {
					// if we already brought in a work address, or if other address is home, put the home address into Other fields
					if ((eba.work_address != null || otherAddressLabel.contains('Home')) && c.otherStreet == null)
						fillAddress(eba.home_address, (sobject)c, 'Other', overwrite);
					else if (c.MailingStreet == null)
						fillAddress(eba.home_address, (sobject)c, 'Mailing', overwrite);
				}

				// fill contact fields if they are null
				if (c.salutation == null || (overwrite && eba.prefix != null))
					c.salutation = eba.prefix;
				if (c.title == null || (overwrite && eba.job_title != null))
					c.title = eba.job_title;
				if (c.birthdate == null || (overwrite && eba.birth_date != null))
					c.birthdate = eba.birth_date;
				if (c.phone == null || (overwrite && eba.work_phone != null))
					c.phone = eba.work_phone;
				if (c.homePhone == null || (overwrite && eba.home_phone != null))
					c.homePhone = eba.home_phone;
				if (c.mobilePhone == null || (overwrite && eba.cell_phone != null))
					c.mobilePhone = eba.cell_phone;					
			}					
		}
		
		// insert or update, mapping the results by the index of the attendee import record
		map<integer, database.saveResult> leadResultMap = new map<integer, database.saveResult>();
		map<integer, database.upsertResult> contactResultMap = new map<integer, database.upsertResult>();
		if (!leadsToInsert.isEmpty()) {
			//system.debug(logginglevel.warn, leadsToInsert);
			list<database.saveResult> res = database.insert(leadsToInsert, false);
			//system.debug(logginglevel.warn, res);
			for (integer i = 0; i < res.size(); i++)
				leadResultMap.put(leadInsertIndexes[i], res[i]);
		}
		if (!contactsToUpsert.isEmpty()) {
			//system.debug(logginglevel.warn, contactsToUpsert);
			list<database.UpsertResult> res = database.upsert(contactsToUpsert, false);
			//system.debug(logginglevel.warn, res);
			for (integer i = 0; i < res.size(); i++)
				contactResultMap.put(contactUpsertIndexes[i], res[i]);
		}
		
		// next we create or update a campaign member for each person
		map<integer, database.upsertResult> cmResultMap = new map<integer, database.upsertResult>();
		if (campaignId != null) { 
			list<campaignMember> cmsToUpsert = new list<campaignMember>();
			list<integer> cmUpsertIndexes = new list<integer>();
			set<id> upsertSet = new set<id>();
			
			for (integer i = 0; i < ebaList.size(); i++) {		
				Eventbrite.Attendee eba = ebaList[i]; 

				id conId = (indexContactMap.containsKey(i)) ? indexContactMap.get(i).id : null;
				id leadId = (indexLeadMap.containsKey(i)) ? indexLeadMap.get(i).id : null;
				id personId = (conId != null) ? conId : leadId;
				campaignMember cm; 
			 	if (memberMap.containsKey(personId)) {
			 		cm = memberMap.get(personId);
			 	} else {
			 		cm = new campaignmember(
			 			contactId = conId,
			 			leadId = leadId,
			 			campaignId = campaignId,
			 			Eventbrite_Ticket_Quantity__c = 0,
			 			Eventbrite_Attendees_Checked_In__c = 0
			 		);
			 		memberMap.put(personId, cm);
			 	}
		 		if (!upsertSet.contains(personId)) {
		 			cmsToUpsert.add(cm);
		 			cmUpsertIndexes.add(i);
		 			upsertSet.add(personId);
		 		}
			 	cm.status = settings.Campaign_Member_Status__c;
			 	
			 	// set the ticket type
			 	string ticketName = ticketNameMap.get(eba.ticket_id);
			 	cm.Eventbrite_Ticket_Type__c = (cm.Eventbrite_Ticket_Type__c == null || cm.Eventbrite_Ticket_Type__c == ticketName) ?
			 		ticketName : 'Multiple Types';
			 	cm.Event_Date_and_Time__c = eba.event_date;
			 	
			 	// check for barcodeId(s) and total qty and update them
			 	set<string> barcodes = new set<string>();
				set<string> checkins = new set<string>();
			 	if (cm.eventbrite_barcodes__c != null) {
			 		barcodes.addAll(cm.eventbrite_barcodes__c.split(';'));
			 	}
			 	if (cm.eventbrite_checkins__c != null) {
			 		checkins.addAll(cm.eventbrite_checkins__c.split(';'));
			 	}
			 	if (eba.barcodes != null) {
			 		for (Eventbrite.Barcode ebc : eba.barcodes) {
						if (!barcodes.contains(ebc.id)) {	
							cm.eventbrite_barcodes__c = (cm.eventbrite_barcodes__c == null) ?
								ebc.id : (cm.eventbrite_barcodes__c + ';' + ebc.id); 		 			
			 				barcodes.add(ebc.id);

			 				// for new barcodes, increment the ticket quantity
			 				if (cm.Eventbrite_Ticket_Quantity__c == null) 
			 					cm.Eventbrite_Ticket_Quantity__c = 1;
			 				else
			 					cm.Eventbrite_Ticket_Quantity__c += 1;
						}
						if (ebc.status == 'used' && !checkins.contains(ebc.id)) {	
							cm.eventbrite_checkins__c = (cm.eventbrite_checkins__c == null) ?
								ebc.id : (cm.eventbrite_checkins__c + ';' + ebc.id); 		 			
			 				barcodes.add(ebc.id);

							// for new checkins, increment the attendees
							if (cm.Eventbrite_Attendees_Checked_In__c == null) 
			 					cm.Eventbrite_Attendees_Checked_In__c = 1;
			 				else
			 					cm.Eventbrite_Attendees_Checked_In__c += 1;
						}
			 		}
			 	} else if (eba.barcode != null) {     // this can be deprecated once we are getting barcode details
			 		for (string bc : eba.barcode) {
						if (!barcodes.contains(bc)) {	
							cm.eventbrite_barcodes__c = (cm.eventbrite_barcodes__c == null) ?
								bc : (cm.eventbrite_barcodes__c + ';' + bc); 		 			
			 				barcodes.add(bc);
			 				// for new barcodes, add the ticket quantity to the total
			 				if (cm.Eventbrite_Ticket_Quantity__c == null) cm.Eventbrite_Ticket_Quantity__c = 0;
			 				cm.Eventbrite_Ticket_Quantity__c += 1;
						}
			 		}
			 	} else {
			 		cm.Eventbrite_Ticket_Quantity__c = eba.quantity;   // should never happen
			 	}
			 	
				// fill text field for answers - consider when there are answers for multiple attendees in one CM
				if (eba.answers != null) {
					string ansText = '\n';  // '[Attendee #' + eba.id + ']\n';
					if (cm.Eventbrite_Answers__c == null || !cm.Eventbrite_Answers__c.contains(ansText)) {
						for (Eventbrite.Answer ea : eba.answers) {
							ansText += ea.question + '  ' + ea.answer_text + '\n';
						}
						cm.Eventbrite_Answers__c = (cm.Eventbrite_Answers__c == null) ? ansText :
							 cm.Eventbrite_Answers__c + '\n' + ansText;
					}
				}				 	
			}

			// insert or update campaign members
			if (!cmsToUpsert.isEmpty()) {
				list<database.Upsertresult> res = database.upsert(cmsToUpsert, false);
				for (integer i = 0; i < res.size(); i++)
					cmResultMap.put(cmUpsertIndexes[i], res[i]);
			}
		}

	 	// now create an opp
		list<opportunity> oppsToUpsert = new list<opportunity>();
		list<integer> oppUpsertIndexes = new list<integer>();

		// use an id set to make sure we don't duplicate contacts
		set<id> oppSet = new set<id>();
				
		for (integer i = 0; i < ebaList.size(); i++) {		
			Eventbrite.Attendee eba = ebaList[i]; 
			 	
			contact c = indexContactMap.get(i);				
		 	if (c != null && settings.Option_for_Leads_or_Contacts__c == 2 && eba.amount_paid != null && eba.amount_paid > 0) {

				opportunity o;	
				if (orderOppMap.containsKey(eba.order_id)) {
					o = orderOppMap.get(eba.order_id);
					if (o.id != null && !oppSet.contains(o.id)) {
						oppsToUpsert.add(o);
						oppUpsertIndexes.add(i);
						oppSet.add(o.id);
					}					

				 	// check for this attendee id in the opp
					set<string> attendeeIds; 
					if (o.Eventbrite_Attendee_IDs__c != null) 
						attendeeIds = new set<string>(o.Eventbrite_Attendee_IDs__c.split(';'));
					if (attendeeIds == null || !attendeeIds.contains(eba.id)) {
						
						// add the new attendee id
						o.Eventbrite_Attendee_IDs__c = (attendeeIds == null) ? eba.id : o.Eventbrite_Attendee_IDs__c + ';' + eba.id;		 			
	
		 				// for new attendees, add the ticket quantity and amount to the total
		 				if (o.Eventbrite_Ticket_Quantity__c == null) o.Eventbrite_Ticket_Quantity__c = 0;
		 				o.Eventbrite_Ticket_Quantity__c += eba.quantity;
		 				if (o.amount == null) eba.amount_paid = 0;
		 				o.amount += eba.amount_paid;
					}
				} else {
					string oppName = (c.firstname + ' ' + c.lastname + ' Eventbrite Order - ' + ebEvent.title);
					o = new opportunity(
						name = (oppName.length() > 120) ? oppName.substring(0,120) : oppName,
						closedate = eba.created.date(),
						eventbrite_order_id__c = eba.order_id,
						Eventbrite_Attendee_IDs__c = eba.id,
						Eventbrite_Ticket_Quantity__c = eba.quantity,
						amount = eba.amount_paid,
						stagename = settings.Opp_Stage__c
					);
					if (oppRecTypeId != null) 
						o.recordTypeId = oppRecTypeId;
					
					orderOppMap.put(eba.order_id, o);
					oppsToUpsert.add(o);
					oppUpsertIndexes.add(i);

					// for contact roles, we can either let triggers create them or do it manually
					if (oppFieldNames.contains('GWBase__CR_Contact_Id__c')) {						
						o.put('GWBase__CR_Contact_Id__c', c.id);
						o.put('GWBase__CR_Contact_Role__c', settings.Opp_Contact_Role__c);
					}				
				}

			 	// set the ticket type
			 	string ticketName = ticketNameMap.get(eba.ticket_id);
			 	o.Eventbrite_Ticket_Type__c = (o.Eventbrite_Ticket_Type__c == null || o.Eventbrite_Ticket_Type__c == ticketName) ?
			 		ticketName : 'Multiple Types';
				
				if (o.campaignId == null) o.campaignId = campaignId;
				o.eventbrite_ticket_id__c = eba.ticket_id;
				o.eventbrite_event_id__c = ebEvent.id;
				o.eventbrite_discount__c = eba.discount;
				o.Event_Date_and_Time__c = (eba.event_date != null) ? eba.event_date : ebEvent.start_date;
				try {
					o.put('CurrencyIsoCode', eba.currency_code);
				} catch (exception e) {}
				if (eba.notes != null && o.description == null)
					o.description = eba.notes;
				
				// fill text field for answers - consider when there are answers for multiple attendees in one order
				if (eba.answers != null) {
					string ansText = '[' + c.firstname + ' ' + c.lastname + ' - Attendee #' + eba.id + ']\n';
					if (o.Eventbrite_Answers__c == null || !o.Eventbrite_Answers__c.contains(ansText)) {
						for (Eventbrite.Answer ea : eba.answers) {
							ansText += ea.question + '  ' + ea.answer_text + '\n';
						}
						o.Eventbrite_Answers__c = (o.Eventbrite_Answers__c == null) ? ansText :
							 o.Eventbrite_Answers__c + '\n' + ansText;
					}
				}	
		 	}
		}

		// now insert and update
		list<OpportunityContactRole> ocrsToInsert = new list<OpportunityContactRole>();
		map<integer, database.upsertResult> oppResultMap = new map<integer, database.upsertResult>();  
		if (!oppsToUpsert.isEmpty()) {
			//system.debug(logginglevel.warn, oppsToUpsert);
			list<database.Upsertresult> srList = database.upsert(oppsToUpsert, false);
			for (integer i = 0; i < srList.size(); i++) {
				database.Upsertresult sr = srList[i];
				oppResultMap.put(oppUpsertIndexes[i], sr);
				//system.debug(logginglevel.warn, sr);

				// for inserts, create contact role (if we did not already do it by trigger in GW Base)
				if (sr.isCreated() && sr.isSuccess() && !oppFieldNames.contains('GWBase__CR_Contact_Id__c')) {

					contact con = indexContactMap.get(oppUpsertIndexes[i]);					
					ocrsToInsert.add( new OpportunityContactRole( 
						opportunityId = sr.getId(), 
						contactId = con.id, 
						role = settings.Opp_Contact_Role__c 
					));
				}
			}
		}

		// insert contact roles
		if (!ocrsToInsert.isEmpty())
			insert ocrsToInsert;
		
		// create result records
		string contactLabel = Describe.getObjectLabel('Contact').toLowerCase();
		string leadLabel = Describe.getObjectLabel('Lead').toLowerCase();
		string oppLabel = Describe.getObjectLabel('Opportunity').toLowerCase();
		
		list<ImportAttendeeResult> resultList = new list<ImportAttendeeResult>();
		for (integer i = 0; i < ebaList.size(); i++) {		
			Eventbrite.Attendee eba = ebaList[i]; 
			 	
			ImportAttendeeResult r = new ImportAttendeeResult();
			if (indexLeadMap.containsKey(i)) {
				lead l = indexLeadMap.get(i);		
				database.SaveResult leadResult = leadResultMap.get(i);
				if (leadResult == null) {
					r.summary = 'Error! No ' + leadLabel + ' was created. ';
				} else if (leadResult.isSuccess()) {
					r.summary = 'Created ' + leadLabel + '. ';
					r.firstname = l.firstname;
					r.lastname = l.lastname;
					r.link = '/' + l.id;
				} else {
					list<database.Error> errs = leadResult.getErrors();
					r.summary = 'Failed to create ' + leadLabel + '; ';
					for (database.error err : errs) 
						r.summary += err.getMessage() + ' ';
				}
			} else if (indexContactMap.containsKey(i)) {
				contact c = indexContactMap.get(i);		
				database.UpsertResult contactResult = contactResultMap.get(i);
				if (contactResult == null) {
					r.summary = 'Same ' + contactLabel + ' from another attendee record. ';
					r.firstname = c.firstname;
					r.lastname = c.lastname;
					r.link = '/' + c.id;
				} else if (contactResult.isSuccess()) {
					r.summary = contactResult.isCreated() ? 
						'Created ' + contactLabel + '. ' : 
						'Updated matching ' + contactLabel + '. ';
					r.firstname = c.firstname;
					r.lastname = c.lastname;
					r.link = '/' + c.id;
				} else {
					list<database.Error> errs = contactResult.getErrors();
					r.summary = 'Failed to create ' + contactLabel + '; ';
					for (database.error err : errs) 
						r.summary += err.getMessage() + ' ';
				}
				
				if (orderOppMap.containsKey(eba.order_id)) {
					opportunity o = orderOppMap.get(eba.order_id);
					database.UpsertResult oppResult = oppResultMap.get(i);
					if (oppResult == null) {
						r.summary += 'Same ' + oppLabel + ' from another attendee record. ';
						r.opportunityName = o.name;
						r.opportunityLink = '/' + o.id;
					} else if (oppResult.isSuccess()) {
						r.summary += oppResult.isCreated() ? 
							'Created order ' + oppLabel + '. ' : 
							'Updated ' + oppLabel + ' with matching Order ID. ';
						r.opportunityName = o.name;
						r.opportunityLink = '/' + o.id;
					} else {
						list<database.Error> errs = oppResult.getErrors();
						r.summary += 'Failed to create ' + oppLabel + '; ';
						for (database.error err : errs) 
							r.summary += err.getMessage() + ' ';
					}
				}
			} else {
				r.summary = 'Error! Nothing was created.';
			}	
			resultList.add(r);						 	
		}
		
		// update settings and return the results
		upsert settings; 
		return resultList;		
	}

	static void fillAddress(Eventbrite.Address addr, sobject o, string addrPrefix, boolean overwrite) {
		string ap = (addrPrefix == null) ? '' : addrPrefix;
		if (overwrite || o.get((ap + 'Street')) == null) {
			o.put(ap + 'Street', addr.address);
			o.put(ap + 'City', addr.city);
			o.put(ap + 'State', addr.region);
			o.put(ap + 'PostalCode', addr.postal_code);
			o.put(ap + 'Country', addr.country);
		}
	}

	@RemoteAction
	public static list<string> getCampaignMemberStatuses(string sCampaignId) {
		list<string> statuses = new list<string>();
		
		for (campaignMemberStatus cm : [select Label from CampaignMemberStatus 
			where campaignId =: sCampaignId order by SortOrder]) 
			
			statuses.add(cm.Label);
			
		return statuses;
	}
	
	static testmethod void testEB() {
		EventbriteConnectController ebc = new EventbriteConnectController();
		system.assert(ebc.settingsJson != null);
		
		insert new campaign(name = 'test', isactive=true);
		list<campaign> c = eventbriteConnectController.getCampaignList(50);
		system.assert(!c.isEmpty());
		CreateCampaignResult ccr = eventbriteConnectController.createCampaign('foo',null,null,system.today(),null, 'In Progress', null);
		list<string> cs = getCampaignMemberStatuses(ccr.campaignId);
		system.assert(!cs.isEmpty());

		account acct = new account(name='Groundwire ConsultingTEST');
		insert acct;

		string oneEvent = '{"box_header_text_color": "005580", "link_color": "EE6600", "box_background_color": "FFFFFF", "timezone": "US/Pacific", "box_border_color": "D5D5D3", "logo": "http://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "organizer": {"url": "http://www.eventbrite.com/org/515399719", "description": "", "id": 515399719, "name": ""}, "background_color": "FFFFFF", "id": 586701841, "category": "", "box_header_background_color": "EFEFEF", "capacity": 5000, "num_attendee_rows": 5, "title": "Test Free Event", "start_date": "2011-02-16 13:00:00", "status": "Completed", "description": "", "end_date": "2011-02-16 16:00:00", "tags": "", "text_color": "005580", "title_text_color": "", "tickets": [{"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "0.00", "quantity_sold": 7, "visible": "true", "currency": "USD", "quantity_available": 20, "type": 0, "id": 9196395, "name": "Free Ticket"}}, {"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "50.00", "quantity_sold": 0, "visible": "true", "currency": "USD", "quantity_available": 100, "type": 0, "id": 9960065, "name": "Ticket plus Donation"}}], "created": "2010-02-24 10:55:06", "url": "http://www.eventbrite.com/event/586701841", "box_text_color": "000000", "privacy": "Public", "venue": {"city": "Seattle", "name": "Groundwire", "country": "United States", "region": "WA", "longitude": -122.336787, "postal_code": "98101", "address_2": "", "address": "1402 3rd Ave", "latitude": 47.609093000000001, "country_code": "US", "id": 422693, "Lat-Long": "47.609093 / -122.336787"}, "modified": "2011-02-16 20:30:34", "logo_ssl": "https://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "repeats": "no"}';
		string oneAttendee = '{"last_name": "CallahanTEST", "answers": [{"answer": {"answer_text": "it is so deep", "question": "In your own words, please describe the link between love and loss.", "question_type": "text", "question_id": 1719139}}], "home_address": "", "suffix": "", "home_postal_code": "98115", "currency": "USD", "prefix": "", "id": 17348011, "first_name": "Bob", "order_type": "Free Order", "event_id": 586701841, "home_address_2": "", "blog": "", "ticket_id": 9196395, "home_phone": "206-123-4567", "event_date": "", "email": "evan+bobtest@groundwire.org", "job_title": "", "website": "", "home_country_code": "US", "home_city": "", "order_id": 13070182, "company": "Groundwire ConsultingTEST", "barcode": "1307018217348011001,1307018217348011002", "home_region": "WA", "discount": "", "amount_paid": "1.11", "home_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "", "cell_phone": "765.4848x89", "notes": "Testing", "quantity": 2}';
		string settingsJson = '{"attributes":{"type":"gweb__Eventbrite_Connector_Settings__c","url":"/services/data/v23.0/sobjects/gweb__Eventbrite_Connector_Settings__c/a00U0000001zLU3IAM"},"Name":"Eventbrite Connector Settings (User)","SetupOwnerId":"005U0000000Zvj3IAC","gweb__Opp_Stage__c":"Closed Won","LastModifiedById":"005U0000000Zvj3IAC","SystemModstamp":"2011-11-30T22:02:41.000+0000","CreatedById":"005U0000000Zvj3IAC","gweb__Use_Existing_Contact__c":true,"CreatedDate":"2011-11-30T22:02:41.000+0000","LastModifiedDate":"2011-11-30T22:02:41.000+0000","IsDeleted":false,"Id":"a00U0000001zLU3IAM","gweb__Create_Accounts__c":true,"gweb__API_User_Key__c":"12664528613477948638","gweb__Username__c":"","gweb__Password__c":"","gweb__Campaign_Type_for_New_Campaigns__c":"Conference","gweb__Campaign_Member_Status__c":"Sent","gweb__Lead_Source__c":"Phone Inquiry","gweb__Opp_Contact_Role__c":"Other","gweb__Option_for_Campaign__c":0,"gweb__Option_for_Leads_or_Contacts__c":2,"gweb__Overwrite_Contact_Detail__c":true}';

		string contactLabel = Describe.getObjectLabel('Contact').toLowerCase();
		string leadLabel = Describe.getObjectLabel('Lead').toLowerCase();
		string oppLabel = Describe.getObjectLabel('Opportunity').toLowerCase();

		list<ImportAttendeeResult> result = 
			EventbriteConnectController.importAttendees(oneEvent, new list<string>{oneAttendee}, settingsJson, ccr.CampaignId, 'Created from Eventbrite Event' );

		system.assertEquals(1, result.size());
		system.assertEquals('CallahanTEST', result[0].lastname);
		system.assertEquals('Created ' + contactLabel + '. Created order ' + oppLabel + '. ', result[0].summary);
		
		list<campaignMember> cm = [select id, status, contactid, eventbrite_answers__c from campaignmember where campaign.id =: ccr.CampaignId];
		system.assertEquals(1, cm.size());
		system.assertEquals('Sent', cm[0].status);
		system.assert(cm[0].eventbrite_answers__c.contains('In your own words'));
		
		list<opportunity> oo = [select id, name, campaignId, amount, eventbrite_answers__c, eventbrite_ticket_type__c from opportunity where campaignId =: ccr.campaignId];
		system.assertEquals(1, oo.size());
		system.assertEquals('Bob CallahanTEST Eventbrite Order - Test Free Event', oo[0].name);
		system.assertEquals(1.11, oo[0].amount);
		system.assert(oo[0].eventbrite_answers__c.contains('In your own words'));
		system.assertEquals('Free Ticket', oo[0].eventbrite_ticket_type__c);
		
		list<opportunitycontactrole> ocr = [select id, contactId, role from opportunitycontactrole where opportunityId =: oo[0].id];
		system.assertEquals(cm[0].contactid, ocr[0].contactid);
		system.assertEquals('Other', ocr[0].role);

		// now do it again to update
		list<string> attendees = new list<string>{
			// same person as before
			'{"last_name": "CallahanTEST", "home_address": "", "suffix": "", "home_postal_code": "98115", "currency": "USD", "prefix": "", "id": 17348011, "first_name": "Bobby", "order_type": "Free Order", "event_id": 586701841, "home_address_2": "", "blog": "", "ticket_id": 9196395, "home_phone": "425-999-9999", "event_date": "", "email": "evan+bobtest@groundwire.org", "job_title": "Jester", "website": "", "home_country_code": "US", "home_city": "", "order_id": 13070182, "company": "", "barcode": "1307018217348011001,1307018217348011002", "home_region": "WA", "discount": "", "amount_paid": "1.00", "home_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "", "cell_phone": "765.4848x89", "notes": "", "quantity": 2}',
			// first person again, new order
			'{"last_name": "CallahanTEST", "home_address": "123 4th", "suffix": "", "home_postal_code": "98115", "currency": "USD", "prefix": "", "id": 17348012, "first_name": "Bob", "order_type": "Free Order", "event_id": 586701841, "home_address_2": "#1234", "blog": "", "ticket_id": 9196395, "home_phone": "", "event_date": "", "email": "evan+bobtest@groundwire.org", "job_title": "", "website": "", "home_country_code": "US", "home_city": "Seattle", "order_id": 13070183, "company": "", "barcode": "1307018217348011003", "home_region": "WA", "discount": "", "amount_paid": "1.00", "home_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "2010-06-28", "cell_phone": "765.4848x89", "notes": "Testing", "quantity": 1}',
			// new person, new order
			'{"last_name": "MagnusonTEST", "home_address": "123 4th", "suffix": "", "home_postal_code": "98115", "currency": "USD", "prefix": "", "id": 17348013, "first_name": "Bob", "order_type": "Free Order", "event_id": 586701841, "home_address_2": "#1234", "blog": "", "ticket_id": 9196395, "home_phone": "", "event_date": "", "email": "eric+bob@groundwire.org", "job_title": "", "website": "", "home_country_code": "US", "home_city": "Seattle", "order_id": 13070184, "company": "", "barcode": "1307018217348011004", "home_region": "WA", "discount": "", "amount_paid": "1.00", "home_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "2010-06-28", "cell_phone": "765.4848x89", "notes": "Testing", "quantity": 1}',
			// another person, but same as previous order
			'{"last_name": "KnoxTEST", "home_address": "123 4th", "suffix": "", "home_postal_code": "98115", "currency": "USD", "prefix": "", "id": 17348014, "first_name": "Bob", "order_type": "Free Order", "event_id": 586701841, "home_address_2": "#1234", "blog": "", "ticket_id": 9196395, "home_phone": "", "event_date": "", "email": "sam+bob@groundwire.org", "job_title": "", "website": "", "home_country_code": "US", "home_city": "Seattle", "order_id": 13070184, "company": "GroundwireTEST", "barcode": "1307018217348011005", "home_region": "WA", "discount": "", "amount_paid": "1.00", "home_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "2010-06-28", "cell_phone": "765.4848x89", "notes": "Testing", "quantity": 1}',
			// another person, zero dollars
			'{"last_name": "FosterTEST", "work_address": "123 4th", "suffix": "", "work_postal_code": "98115", "currency": "USD", "prefix": "", "id": 17348014, "first_name": "Bob", "order_type": "Free Order", "event_id": 586701841, "work_address_2": "", "blog": "", "ticket_id": 9196395, "home_phone": "", "event_date": "", "email": "ryan+bob@groundwire.org", "job_title": "", "website": "", "work_country_code": "US", "work_city": "Seattle", "order_id": 13070185, "company": "GroundwireTEST", "barcode": "1307018217348011006", "work_region": "WA", "discount": "", "amount_paid": "0.00", "work_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "2010-06-28", "cell_phone": "765.4848x89", "notes": "Testing", "quantity": 1}'
		};
		settingsJson = '{"attributes":{"type":"gweb__Eventbrite_Connector_Settings__c","url":"/services/data/v23.0/sobjects/gweb__Eventbrite_Connector_Settings__c/a00U0000001zLU3IAM"},"Name":"Eventbrite Connector Settings (User)","SetupOwnerId":"005U0000000Zvj3IAC","gweb__Opp_Stage__c":"Closed Won","LastModifiedById":"005U0000000Zvj3IAC","SystemModstamp":"2011-11-30T22:02:41.000+0000","CreatedById":"005U0000000Zvj3IAC","gweb__Use_Existing_Contact__c":true,"CreatedDate":"2011-11-30T22:02:41.000+0000","LastModifiedDate":"2011-11-30T22:02:41.000+0000","IsDeleted":false,"Id":"a00U0000001zLU3IAM","gweb__Create_Accounts__c":true,"gweb__API_User_Key__c":"12664528613477948638","gweb__Username__c":"","gweb__Password__c":"","gweb__Campaign_Type_for_New_Campaigns__c":"Conference","gweb__Campaign_Member_Status__c":"Responded","gweb__Lead_Source__c":"Phone Inquiry","gweb__Opp_Contact_Role__c":"Other","gweb__Option_for_Campaign__c":0,"gweb__Option_for_Leads_or_Contacts__c":2,"gweb__Overwrite_Contact_Detail__c":true}';
		
		result = 
			EventbriteConnectController.importAttendees(oneEvent, attendees, settingsJson, ccr.CampaignId, 'Created from Eventbrite Event' );

		system.assertEquals(5, result.size());
		system.assertEquals('Bob', result[0].firstname);
		system.assertEquals('Updated matching ' + contactLabel + '. Updated ' + oppLabel + ' with matching Order ID. ', result[0].summary);
		system.assertEquals('Same ' + contactLabel + ' from another attendee record. Created order ' + oppLabel + '. ', result[1].summary);
		system.assertEquals('Created ' + contactLabel + '. Created order ' + oppLabel + '. ', result[2].summary);
		system.assertEquals('Created ' + contactLabel + '. Same ' + oppLabel + ' from another attendee record. ', result[3].summary);
		system.assertEquals('Created ' + contactLabel + '. ', result[4].summary);
		
		cm = [select id, contact.title, contact.accountid, contact.account.name, contact.account.billingstreet, contact.homephone, status 
			from campaignmember where campaign.id =: ccr.CampaignId order by contact.lastname];
		system.assertEquals(4, cm.size());
		system.assertEquals('Responded', cm[0].status);
		system.assertEquals('425-999-9999', cm[0].contact.homephone);
		system.assertEquals('Jester', cm[0].contact.title);
		system.assertEquals(acct.id, cm[0].contact.accountid);
		system.assertEquals('GroundwireTEST', cm[1].contact.account.name);
		system.assertEquals('GroundwireTEST', cm[2].contact.account.name);
		system.assertEquals('123 4th', cm[2].contact.account.billingstreet);
		system.assertEquals(null, cm[3].contact.account.name);
		
		oo = [select id, name, description, campaignId from opportunity where campaignId =: ccr.campaignId];
		system.assertEquals(3, oo.size());
		system.assertEquals('Bob CallahanTEST Eventbrite Order - Test Free Event', oo[0].name);
		system.assertEquals('Testing', oo[0].description);
	}	

	static testmethod void testEBleads() {
		insert new campaign(name = 'test', isactive=true);
		list<campaign> c = eventbriteConnectController.getCampaignList(50);
		CreateCampaignResult ccr = eventbriteConnectController.createCampaign('foo',null,null,system.today(),null, 'In Progress', null);
		list<string> cs = getCampaignMemberStatuses(ccr.campaignId);
		
		string oneEvent = '{"box_header_text_color": "005580", "link_color": "EE6600", "box_background_color": "FFFFFF", "timezone": "US/Pacific", "box_border_color": "D5D5D3", "logo": "http://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "organizer": {"url": "http://www.eventbrite.com/org/515399719", "description": "", "id": 515399719, "name": ""}, "background_color": "FFFFFF", "id": 586701841, "category": "", "box_header_background_color": "EFEFEF", "capacity": 5000, "num_attendee_rows": 5, "title": "Test Free Event", "start_date": "2011-02-16 13:00:00", "status": "Completed", "description": "", "end_date": "2011-02-16 16:00:00", "tags": "", "text_color": "005580", "title_text_color": "", "tickets": [{"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "0.00", "quantity_sold": 7, "visible": "true", "currency": "USD", "quantity_available": 20, "type": 0, "id": 9196395, "name": "Free Ticket"}}, {"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "50.00", "quantity_sold": 0, "visible": "true", "currency": "USD", "quantity_available": 100, "type": 0, "id": 9960065, "name": "Ticket plus Donation"}}], "created": "2010-02-24 10:55:06", "url": "http://www.eventbrite.com/event/586701841", "box_text_color": "000000", "privacy": "Public", "venue": {"city": "Seattle", "name": "Groundwire", "country": "United States", "region": "WA", "longitude": -122.336787, "postal_code": "98101", "address_2": "", "address": "1402 3rd Ave", "latitude": 47.609093000000001, "country_code": "US", "id": 422693, "Lat-Long": "47.609093 / -122.336787"}, "modified": "2011-02-16 20:30:34", "logo_ssl": "https://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "repeats": "no"}';
		list<string> attendees = new list<string>{
			'{"last_name": "CallahanTEST", "home_address": "", "suffix": "", "home_postal_code": "98236", "currency": "USD", "prefix": "", "id": 17348011, "first_name": "Bob", "order_type": "Free Order", "event_id": 586701841, "home_address_2": "", "blog": "", "ticket_id": 9196395, "home_phone": "", "event_date": "", "email": "evan+bobtest@groundwire.org", "job_title": "", "website": "", "home_country_code": "US", "home_city": "", "order_id": 13070182, "company": "", "barcode": "1307018217348011001,1307018217348011002", "home_region": "WA", "discount": "", "amount_paid": "0.00", "home_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "", "cell_phone": "765.4848x89", "notes": "", "quantity": 2}',
			'{"last_name": "MagnusonTEST", "home_address": "123 4th", "suffix": "", "home_postal_code": "98115", "currency": "USD", "prefix": "", "id": 17348012, "first_name": "Bob", "order_type": "Free Order", "event_id": 586701841, "home_address_2": "#1234", "blog": "", "ticket_id": 9196395, "home_phone": "", "event_date": "", "email": "eric+bob@groundwire.org", "job_title": "", "website": "", "home_country_code": "US", "home_city": "Seattle", "order_id": 13070182, "company": "", "barcode": "1307018217348011003", "home_region": "WA", "discount": "", "amount_paid": "0.00", "home_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "2010-06-28", "cell_phone": "765.4848x89", "notes": "Testing", "quantity": 1}'
		};
		string settingsJson = '{"attributes":{"type":"gweb__Eventbrite_Connector_Settings__c","url":"/services/data/v23.0/sobjects/gweb__Eventbrite_Connector_Settings__c/a00U0000001zLU3IAM"},"Name":"Eventbrite Connector Settings (User)","SetupOwnerId":"005U0000000Zvj3IAC","gweb__Opp_Stage__c":"Closed Won","LastModifiedById":"005U0000000Zvj3IAC","SystemModstamp":"2011-11-30T22:02:41.000+0000","CreatedById":"005U0000000Zvj3IAC","gweb__Use_Existing_Contact__c":true,"CreatedDate":"2011-11-30T22:02:41.000+0000","LastModifiedDate":"2011-11-30T22:02:41.000+0000","IsDeleted":false,"Id":"a00U0000001zLU3IAM","gweb__Create_Accounts__c":true,"gweb__API_User_Key__c":"12664528613477948638","gweb__Username__c":"","gweb__Password__c":"","gweb__Campaign_Type_for_New_Campaigns__c":"Conference","gweb__Campaign_Member_Status__c":"Responded","gweb__Lead_Source__c":"Phone Inquiry","gweb__Opp_Contact_Role__c":"Economic Buyer","gweb__Option_for_Campaign__c":0,"gweb__Option_for_Leads_or_Contacts__c":0,"gweb__Overwrite_Contact_Detail__c":false}';
		
		string leadLabel = Describe.getObjectLabel('Lead').toLowerCase();

		list<ImportAttendeeResult> result = 
			EventbriteConnectController.importAttendees(oneEvent, attendees, settingsJson, ccr.CampaignId, 'Created from Eventbrite Event' );

		system.assertEquals(2, result.size());
		system.assertEquals('Created ' + leadLabel + '. ', result[0].summary);
		system.assertEquals('CallahanTEST', result[0].lastname);
		
		list<campaignMember> cm = [select id, status, lead.postalcode from campaignmember where campaign.id =: ccr.CampaignId];
		system.assertEquals(2, cm.size());
		system.assertEquals('Responded', cm[0].status);
		system.assertEquals('98236', cm[0].lead.postalcode);
		system.assertEquals('98115', cm[1].lead.postalcode);
		
		list<opportunity> oo = [select id, name, campaignId from opportunity where campaignId =: ccr.campaignId];
		system.assertEquals(0, oo.size());		
	}	

	static testmethod void testEBLeadAndContact() {
		insert new campaign(name = 'test', isactive=true);
		list<campaign> c = eventbriteConnectController.getCampaignList(50);
		CreateCampaignResult ccr = eventbriteConnectController.createCampaign('foo',null,null,system.today(),null, 'In Progress', null);
		contact c1 = new contact(lastname='MagnusonTEST', email='eric+bob@groundwire.org');
		insert c1;
		contact c2 = new contact(lastname='Magna-SUN', email='eric+bob@groundwire.org');
		insert c2;
		
		string oneEvent = '{"box_header_text_color": "005580", "link_color": "EE6600", "box_background_color": "FFFFFF", "timezone": "US/Pacific", "box_border_color": "D5D5D3", "logo": "http://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "organizer": {"url": "http://www.eventbrite.com/org/515399719", "description": "", "id": 515399719, "name": ""}, "background_color": "FFFFFF", "id": 586701841, "category": "", "box_header_background_color": "EFEFEF", "capacity": 5000, "num_attendee_rows": 5, "title": "Test Free Event", "start_date": "2011-02-16 13:00:00", "status": "Completed", "description": "", "end_date": "2011-02-16 16:00:00", "tags": "", "text_color": "005580", "title_text_color": "", "tickets": [{"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "0.00", "quantity_sold": 7, "visible": "true", "currency": "USD", "quantity_available": 20, "type": 0, "id": 9196395, "name": "Free Ticket"}}, {"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "50.00", "quantity_sold": 0, "visible": "true", "currency": "USD", "quantity_available": 100, "type": 0, "id": 9960065, "name": "Ticket plus Donation"}}], "created": "2010-02-24 10:55:06", "url": "http://www.eventbrite.com/event/586701841", "box_text_color": "000000", "privacy": "Public", "venue": {"city": "Seattle", "name": "Groundwire", "country": "United States", "region": "WA", "longitude": -122.336787, "postal_code": "98101", "address_2": "", "address": "1402 3rd Ave", "latitude": 47.609093000000001, "country_code": "US", "id": 422693, "Lat-Long": "47.609093 / -122.336787"}, "modified": "2011-02-16 20:30:34", "logo_ssl": "https://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "repeats": "no"}';
		list<string> attendees = new list<string>{
			'{"last_name": "CallahanTEST", "home_address": "123 5th", "suffix": "", "home_postal_code": "98236", "currency": "USD", "prefix": "", "id": 17348011, "first_name": "Bob", "order_type": "Free Order", "event_id": 586701841, "home_address_2": "", "blog": "", "ticket_id": 9196395, "home_phone": "", "event_date": "", "email": "evan+bobtest@groundwire.org", "job_title": "", "website": "", "home_country_code": "US", "home_city": "", "order_id": 13070182, "company": "", "barcode": "1307018217348011001,1307018217348011002", "home_region": "WA", "discount": "", "amount_paid": "0.00", "home_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "", "cell_phone": "765.4848x89", "notes": "", "quantity": 2}',
			'{"last_name": "MagnusonTEST", "home_address": "123 4th", "suffix": "", "home_postal_code": "98115", "currency": "USD", "prefix": "", "id": 17348012, "first_name": "Bob", "order_type": "Free Order", "event_id": 586701841, "home_address_2": "#1234", "blog": "", "ticket_id": 9196395, "home_phone": "", "event_date": "", "email": "eric+bob@groundwire.org", "job_title": "", "website": "", "home_country_code": "US", "home_city": "Seattle", "order_id": 13070182, "company": "", "barcodes": [{"barcode": {"status": "unused", "date_modified": "2011-12-28 21:53:20", "checkin_type": 0, "checkin_method": null, "attendee_id": 17348012, "date_created": "2011-12-29 05:53:20", "id": "1307018217348011003", "device_id": null}},{"barcode": {"status": "used", "date_modified": "2011-12-28 21:53:20", "checkin_type": 0, "checkin_method": null, "attendee_id": 17348013, "date_created": "2011-12-29 05:53:20", "id": "1307018217348011004", "device_id": null}}], "home_region": "WA", "discount": "", "amount_paid": "0.00", "home_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "2010-06-28", "cell_phone": "765.4848x89", "notes": "Testing", "quantity": 2}'
		};
		string settingsJson = '{"attributes":{"type":"gweb__Eventbrite_Connector_Settings__c","url":"/services/data/v23.0/sobjects/gweb__Eventbrite_connector_Settings__c/a00U0000001zLU3IAM"},"Name":"Eventbrite Connector Settings (User)","SetupOwnerId":"005U0000000Zvj3IAC","gweb__Opp_Stage__c":"Closed Won","LastModifiedById":"005U0000000Zvj3IAC","SystemModstamp":"2011-11-30T22:02:41.000+0000","CreatedById":"005U0000000Zvj3IAC","gweb__Use_Existing_Contact__c":true,"CreatedDate":"2011-11-30T22:02:41.000+0000","LastModifiedDate":"2011-11-30T22:02:41.000+0000","IsDeleted":false,"Id":"a00U0000001zLU3IAM","gweb__Create_Accounts__c":true,"gweb__API_User_Key__c":"12664528613477948638","gweb__Username__c":"","gweb__Password__c":"","gweb__Campaign_Type_for_New_Campaigns__c":"Conference","gweb__Campaign_Member_Status__c":"Responded","gweb__Lead_Source__c":"Phone Inquiry","gweb__Opp_Contact_Role__c":"Economic Buyer","gweb__Option_for_Campaign__c":0,"gweb__Option_for_Leads_or_Contacts__c":0,"gweb__Overwrite_Contact_Detail__c":false}';
		
		string contactLabel = Describe.getObjectLabel('Contact').toLowerCase();
		string leadLabel = Describe.getObjectLabel('Lead').toLowerCase();

		list<ImportAttendeeResult> result = 
			EventbriteConnectController.importAttendees(oneEvent, attendees, settingsJson, ccr.CampaignId, 'Created from Eventbrite Event' );

		system.assertEquals(2, result.size());
		system.assertEquals('Created ' + leadLabel + '. ', result[0].summary);
		system.assertEquals('CallahanTEST', result[0].lastname);
		system.assertEquals('Magna-SUN', result[1].lastname);
		system.assertEquals('Updated matching ' + contactLabel + '. ', result[1].summary);
		
		list<campaignMember> cm = [select id, campaign.eventbrite_event_id__c, status, Eventbrite_Ticket_Quantity__c, Eventbrite_Attendees_Checked_In__c, contactid, contact.birthdate, lead.postalcode from campaignmember where campaign.id =: ccr.CampaignId order by Eventbrite_Attendees_Checked_In__c];
		system.assertEquals(2, cm.size());
		system.assertEquals('98236', cm[0].lead.postalcode);
		system.assertEquals(2, cm[0].Eventbrite_Ticket_Quantity__c);
		system.assertEquals(0, cm[0].Eventbrite_Attendees_Checked_In__c);
		system.assertEquals(2010, cm[1].contact.birthdate.year());
		system.assertEquals(2, cm[1].Eventbrite_Ticket_Quantity__c);
		system.assertEquals(1, cm[1].Eventbrite_Attendees_Checked_In__c);
		system.assertEquals('586701841', cm[1].campaign.eventbrite_event_id__c);

		list<opportunity> oo = [select id, name, campaignId from opportunity where campaignId =: ccr.campaignId];
		system.assertEquals(0, oo.size());		
	}	
	
	static testmethod void testEBerror() {		
		string oneEvent = '{"box_header_text_color": "005580", "link_color": "EE6600", "box_background_color": "FFFFFF", "timezone": "US/Pacific", "box_border_color": "D5D5D3", "logo": "http://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "organizer": {"url": "http://www.eventbrite.com/org/515399719", "description": "", "id": 515399719, "name": ""}, "background_color": "FFFFFF", "id": 586701841, "category": "", "box_header_background_color": "EFEFEF", "capacity": 5000, "num_attendee_rows": 5, "title": "Test Free Event", "start_date": "2011-02-16 13:00:00", "status": "Completed", "description": "", "end_date": "2011-02-16 16:00:00", "tags": "", "text_color": "005580", "title_text_color": "", "tickets": [{"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "0.00", "quantity_sold": 7, "visible": "true", "currency": "USD", "quantity_available": 20, "type": 0, "id": 9196395, "name": "Free Ticket"}}, {"ticket": {"description": "", "end_date": "2011-02-16 10:00:00", "min": 0, "max": 0, "price": "50.00", "quantity_sold": 0, "visible": "true", "currency": "USD", "quantity_available": 100, "type": 0, "id": 9960065, "name": "Ticket plus Donation"}}], "created": "2010-02-24 10:55:06", "url": "http://www.eventbrite.com/event/586701841", "box_text_color": "000000", "privacy": "Public", "venue": {"city": "Seattle", "name": "Groundwire", "country": "United States", "region": "WA", "longitude": -122.336787, "postal_code": "98101", "address_2": "", "address": "1402 3rd Ave", "latitude": 47.609093000000001, "country_code": "US", "id": 422693, "Lat-Long": "47.609093 / -122.336787"}, "modified": "2011-02-16 20:30:34", "logo_ssl": "https://evbdn.eventbrite.com/s3-s3/eventlogos/3467546/586701841-1.png", "repeats": "no"}';
		string oneAttendee = '{"last_name": "", "home_address": "", "suffix": "", "home_postal_code": "98115", "currency": "BRITISH POUND", "prefix": "", "id": 17348011, "first_name": "Bob", "order_type": "Free Order", "event_id": 586701841, "home_address_2": "", "blog": "", "ticket_id": 9196395, "home_phone": "", "event_date": "", "email": "BOGUS", "job_title": "", "website": "", "home_country_code": "US", "home_city": "", "order_id": 13070182, "company": "", "barcode": "1307018217348011001,1307018217348011002", "home_region": "WA", "discount": "", "amount_paid": "0.00", "home_country": "US", "created": "2010-06-28 01:47:35", "gender": "", "age": "", "modified": "2010-06-28 01:48:07", "affiliate": "", "birth_date": "", "cell_phone": "765.4848x89", "notes": "", "quantity": 2.2}';
		string settingsJson = '{"attributes":{"type":"gweb__Eventbrite_Connector_Settings__c","url":"/services/data/v23.0/sobjects/gweb__Eventbrite_connector_Settings__c/a00U0000001zLU3IAM"},"Name":"Eventbrite Connector Settings (User)","SetupOwnerId":"005U0000000Zvj3IAC","gweb__Opp_Stage__c":"Closed Won","LastModifiedById":"005U0000000Zvj3IAC","SystemModstamp":"2011-11-30T22:02:41.000+0000","CreatedById":"005U0000000Zvj3IAC","gweb__Use_Existing_Contact__c":true,"CreatedDate":"2011-11-30T22:02:41.000+0000","LastModifiedDate":"2011-11-30T22:02:41.000+0000","IsDeleted":false,"Id":"a00U0000001zLU3IAM","gweb__Create_Accounts__c":true,"gweb__API_User_Key__c":"12664528613477948638","gweb__Username__c":"","gweb__Password__c":"","gweb__Campaign_Type_for_New_Campaigns__c":"Conference","gweb__Campaign_Member_Status__c":"Responded","gweb__Lead_Source__c":"Phone Inquiry","gweb__Opp_Contact_Role__c":"Economic Buyer","gweb__Option_for_Campaign__c":0,"gweb__Option_for_Leads_or_Contacts__c":2,"gweb__Overwrite_Contact_Detail__c":false}';
		
		string contactLabel = Describe.getObjectLabel('Contact').toLowerCase();

		list<ImportAttendeeResult> result = 
			EventbriteConnectController.importAttendees(oneEvent, new list<string>{oneAttendee}, settingsJson, null, 'Created from Eventbrite Event' );

		system.assertEquals(1, result.size());
		system.assertEquals('Failed to create ' + contactLabel + '; Email: invalid email address: BOGUS ', result[0].summary);		
	}
}