function EventbriteImport($, settings, options) {
  // console.log(settings);
  var ebClient,
    /* DOM Elements */
    container = $('#container'),
    tabs = $('#ebMain').tabs({disabled: [1, 2, 3, 4]}),
    userkey = $('#userkey'),
    email = $('#email'),
    password = $('#password'),
    remember = $('#remember'),
    userkeyWhat = $('#what-userkey a'),
    eventButton = $('#event-continue').button({disabled: true}),
    eventStatus = $('#event-status'),
    campaignButton = $('#campaign-continue').button({disabled: true}),
    campaignStatus = $('#campaign-status'),
    campaignActionButtons = $('#campaign-action').buttonset(),
    campaignAction = $('input[name="campaign-action"]'),
    campaignMemberStatus = $('#campaign-member-status'),
    campaignMemberStatusLabel = campaignMemberStatus.prev('label'),
    campaignNewName = $('#campaign-name').addClass('text ui-widget-content ui-corner-all'),
    campaignNewRecordType = $('table[id$="campaignRecType"] input[type="radio"]'),
    campaignNewType = $('#campaign-type-wrapper select'),
    campaignNewStatus = $('#campaign-status-wrapper select'),
    campaignNewStart = $('#campaign-start-wrapper input').addClass('text ui-widget-content ui-corner-all'),
    campaignNewEnd = $('#campaign-end-wrapper input').addClass('text ui-widget-content ui-corner-all'),
    campaignNewParent = $('#campaign-parent-wrapper input[type="hidden"]').eq(0),
    campaignNewParentText = $('#campaign-parent-wrapper input[type="text"]').addClass('text ui-widget-content ui-corner-all'),
    campaignNewDescription = $('#campaign-description'),
    campaignNewButton = $('#campaign-create').button(),
    importButton = $('#import').button({disabled: true}),
    importStatus = $('#import-status'),
    importActionButtons = $('#import-action').buttonset(),
    importActionContacts = $('#import-action-contacts'),
    importActionContactsOpps = $('#import-action-contacts-opps'),
    importAction = $('input[name="import-action"]'),
    importIndicator = $('#import-indicator').progressbar({value: 0}),
    matchContacts = $('#match-contacts'),
    contactDescription = $('#contact-description'),
    importCreateAccounts = $('#create-accounts'),
    importOverwriteContacts = $('input[name="overwrite-contact"]'),
    leadSource = $('select[id$="leadSource"]'),
    oppStage = $('select[id$="oppStage"]'),
    oppContactRole = $('select[id$="oppRole"]'),
    oppRecordType = $('table[id$="oppRecordType"] input[type="radio"]'),
    importTypeText = $('.import-type-text'),
    /* Dialogs */
    importProgress = $('#import-progress').dialog({
      autoOpen: false,
      closeOnEscape: false,
      dialogClass: 'no-close-button',
      modal: true,
      resizable: false,
      width: 450,
      buttons: {
        Cancel: function() {
          $(this).dialog('close');
          importButton.button('enable');
        }
      }
    }),
    errorMessages = $('#error-messages > div').dialog({
      autoOpen: false,
      resizable: false,
      buttons: {
        Ok: function() {
      		$(this).dialog('close');
      	}
      }
    }),
    newCampaign = $('#campaign-new').dialog({
      autoOpen: false,
      modal: true,
      resizable: false,
      width: 550,
      buttons: [
        {
          text: 'Create ' + options.labels.campaign,
          click: function() {
            if (validateCampaignInput()) {
              gweb.EventbriteImportController.createCampaign.apply(gweb.EventbriteImportController, extractCampaignArguments(function(response, e) {
                if (handleSalesforceError(e)) {
                  // Put the member statuses in our campaign member status cache.
                  campaignMemberStatusCache[response.campaignId] = response.campaignMemberStatuses;
                  // Add the campaign to our campaign table.
                  campaignData.addItem(createCampaignData(response));
                  // Sort the table by descending modified date.
                  campaignGrid.setSortColumn('LastModifiedDate', false);
                  campaignData.fastSort('LastModifiedDate', false);
                  // Select the new campaign.
                  campaignGrid.setSelectedRows([0]);
                  // Close the dialog.
                  newCampaign.dialog('close');
                }
              }));
            }
          }
        },
        {
          text: 'Cancel',
          click: function() {
            $(this).dialog('close');
          }
        }
      ]
    }),
    aboutUserkey = $('#about-userkey').dialog({
      autoOpen: false,
      resizable: false,
      width: 400,
      buttons: {
        'Get a User Key': function() {
          window.open('http://www.eventbrite.com/userkeyapi');
      		$(this).dialog('close');
      	},
        Cancel: function() {
      		$(this).dialog('close');
      	}
      }
    }),
    /* Event Grid */
    eventContainer = $("#events"),
    eventTemplate = tmpl('event_template'),
    eventColumns = [
      {id:'events', name:'Events', field:'events', formatter:renderEvent, width: 276}
    ],
    eventData = new Slick.Data.DataView(),
    eventGrid = new Slick.Grid(eventContainer, eventData, eventColumns, {
      multiSelect: false,
      rowHeight: 50
    }),
    /* Attendee Grid */
    attendeeContainer = $("#attendees"),
    attendeeSelector = new Slick.CheckboxSelectColumn({
      cssClass: "slick-cell-checkboxsel"
    }),
    attendeeColumns = [
      attendeeSelector.getColumnDefinition(),
      {id:'first_name', name:'First Name', field:'first_name', sortable:true, width: 140},
      {id:'last_name', name:'Last Name', field:'last_name', sortable:true, width: 140},
      {id:'email', name:'Email', field:'email', width: 202}
    ],
    attendeeData = new Slick.Data.DataView(),
    attendeeGrid = new Slick.Grid(attendeeContainer, attendeeData, attendeeColumns, {}),
    /* Campaign Grid */
    campaignContainer = $("#campaigns"),
    campaignColumns = [
      {id:'Name', name:'Campaign Name', field:'Name', sortable:true, width: 465},
      {id:'Type', name:'Type', field:'Type', sortable:true, width: 150},
      {id:'StartDate', name:'Start Date', field:'StartDate', formatter: salesforeDateFormatter, sortable:true, width: 110},
      {id:'LastModifiedDate', name:'Modified Date', field:'LastModifiedDate', formatter: salesforeDateFormatter, sortable:true, width: 110}
    ],
    campaignData = new Slick.Data.DataView(),
    campaignGrid = new Slick.Grid(campaignContainer, campaignData, campaignColumns, {
      multiSelect: false
    }),
    /* Result Grid */
    resultContainer = $("#results"),
    resultColumns = [
      {id:'firstname', name:'First Name', field:'firstname', sortable:true, formatter: formatResultName, width: 200},
      {id:'lastname', name:'Last Name', field:'lastname', sortable:true, formatter: formatResultName, width: 200},
      {id:'opp', name:'Opportunity', field:'opp', formatter: formatResultOpp, width: 335},
      {id:'summary', name:'Summary', field:'summary', sortable:true, formatter: formatResultSummary, width: 100}
    ],
    resultData = new Slick.Data.DataView(),
    resultGrid = new Slick.Grid(resultContainer, resultData, resultColumns, {}),
    linkTemplate = tmpl('link_template'),
    /* Cache */
    campaignMemberStatusCache = {},
    /* Status */
    importError = false,
    freeEvent = true;
    
  /* Settings */
    
  function simpleSetting(el, settingName, fromSF, toSF, allowNull) {
    if (el.length) {
      var current = settings[settingName];
      if (!(current === '' || current === null || current === undefined)) {
        if (fromSF === undefined) {
          el.val(current);
        } else {
          fromSF(el, current);
        }      
      }
      el.change(function() {
        settings[settingName] = (toSF === undefined) ? el.val() : toSF(el);
      });
      if (!allowNull) {
        el.change();
      }
    }
  };
  
  function checkboxSetting(el, settingName) {
    return simpleSetting(el, settingName, function(el, current) {
      el.prop('checked', current === true);
    }, function(el) {
      return el.is(':checked');
    });
  };
  
  function radioBoolSetting(el, settingName) {
    return simpleSetting(el, settingName, function(el, current) {
      el.filter('input[value="' + current + '"]').prop('checked', true);
    }, function(el) {
      return el.filter(':checked').val() === 'true';
    });
  };
  
  function radioIndexSetting(el, settingName) {
    return simpleSetting(el, settingName, function(el, current) {
      el.filter('input:eq(' + current + ')').prop('checked', true);
    }, function(el) {
      return el.index(el.filter(':checked'));
    }, false);
  };
  
  function radioValueSetting(el, settingName) {
    return simpleSetting(el, settingName, function(el, current) {
      el.filter(function() {
        return $(this).val() === current;
      }).prop('checked', true);
    }, function(el) {
      return el.filter(':checked').val();
    }, false);
  };
  
  function rememberSetting(el, settingName) {
    if (settings[settingName]) {
      el.prop('checked', true);
    }
  };
  
  function getImportArgs(eventJSON, attendees, campaignId, contactDescriptionValue, callback) {
    return [
      eventJSON,
      attendees,
      campaignId,
      contactDescriptionValue,
      settings['gweb__Username__c'] || null,
      (remember.prop('checked')) ? settings['gweb__Password__c'] || null : null,
      settings['gweb__API_User_Key__c'] || null,
      settings['gweb__Option_for_Leads_or_Contacts__c'],
      settings['gweb__Use_Existing_Contact__c'],
      settings['gweb__Overwrite_Contact_Detail__c'],
      settings['gweb__Lead_Source__c'] || null,
      settings['gweb__Create_Accounts__c'],
      settings['gweb__Option_for_Campaign__c'],
      settings['gweb__Campaign_Member_Status__c'] || null,
      settings['gweb__Opp_Contact_Role__c'] || null,
      settings['gweb__Opp_Record_Type_Id__c'] || null,
      settings['gweb__Opp_Stage__c'] || null,
      callback,
      {escape: false}
    ];
  };
  
  /* Error handling */
  
  function handleEventbriteError(response) {
    if (!response.error) {
      return true;
    }
    // console.log(response.error);
    var message = errorMessages
      .filter('#error-' + response.error.error_message.toLowerCase().replace(/[^a-zA-Z0-9]+/g, ''));
    if (message.length != 1) {
      message = errorMessages.filter('#error-default')
      .dialog('option', 'title', response.error.error_type)
      .find('p').text(response.error.error_message).end();
    }
    message.dialog('open');
    return false;
  };
  
  function handleSalesforceError(e) {
    if (e.status) {
      return true;
    }
    // console.log(e);
    var message = errorMessages
      .filter('#error-' + e.message.replace(/[^a-zA-Z0-9]+/g, ''));
    if (message.length != 1) {
      message = errorMessages.filter('#error-default')
      .dialog('option', 'title', 'Salesforce Error: ' + e.method)
      .find('p').text(e.message).end();
    }
    message.dialog('open');
    return false;
  };
  
  /* Grids */

  function initializeGrid(el, grid, data, options) {
    el.data({
      'ebc.selectedIds': [],
      'ebc.updateSelection': true
    });
    
    grid.onSelectedRowsChanged.subscribe(function() {
      if (el.data('ebc.updateSelection')) {
        updateSelectedIds(el, grid, data);
        if (options.selectCallback) {
          options.selectCallback();
        }
      }
    });
    
    data.onRowCountChanged.subscribe(function(e,args) {
      grid.updateRowCount();
      grid.render();
    });

    data.onRowsChanged.subscribe(function(e,args) {
      grid.invalidateRows(args.rows);
      grid.render();
      setSelectedRowsByIds(el, grid, data);
    });
    
    if (options.paginate) {
      var pagerEl = $('<div class="pager-wrapper"><div class="grid-pager"></div></div>')
        .insertAfter(el).find('.grid-pager');
      new Slick.Controls.Pager(data, grid, pagerEl);
    }
    
    if (options.searchable) {
      var searchInput = options.searchInput;
      if (!searchInput) {
        searchInput = $('<input type="text" class="grid-search text ui-widget-content ui-corner-all">');
        searchInput.wrap('<div class="grid-search-wrapper"></div>')
          .before('<label>Search</label>').parent().insertBefore(el);
      }
      
      data.setFilter(filterItem);
      searchInput.keyup(function() {
        data.setFilterArgs({
          searchTerm: $(this).val(),
          searchCols: options.searchCols
        });
        data.refresh();
      }).keyup();
    }
    
    if (options.sortable) {
      grid.onSort.subscribe(function(e, args) {
        var sortcol = args.sortCol.field;
        data.fastSort(sortcol,args.sortAsc);
      });
    }
  };
  
  function updateSelectedIds(el, grid, data) {
    if (grid.getSelectionModel() !== undefined) {
      var pageInfo = data.getPagingInfo(),
        startRow = 0,
        endRow = pageInfo.pageSize || pageInfo.totalRows,
        selectedIds = (grid.getOptions().multiSelect) ? el.data('ebc.selectedIds') : [],
        newRows = grid.getSelectedRows();
      for (var row = startRow; row < endRow; row++) {
        var item = data.getItem(row);
        if (item) {
          if ($.inArray(row, newRows) !== -1 && $.inArray(item.id, selectedIds) === -1) {
            selectedIds.push(item.id);
          } else if ($.inArray(row, newRows) === -1 && $.inArray(item.id, selectedIds) !== -1) {
            selectedIds.splice(selectedIds.indexOf(item.id), 1);
          }
        }
      }
      el.data('ebc.selectedIds', selectedIds);
    }
  };
  
  function setSelectedRowsByIds(el, grid, data) {
    if (grid.getSelectionModel() === undefined) {
      return;
    }
    var selectedRows = [];
    $.each(el.data('ebc.selectedIds'), function(i, id) {
      var row = data.getRowById(id);
      if (row !== undefined) {
        selectedRows.push(row);
      }
    });
    el.data('ebc.updateSelection', false);
    grid.resetActiveCell();
    grid.setSelectedRows(selectedRows);
    el.data('ebc.updateSelection', true);
  };
  
  function resetSelectionCache(el) {
    el.data('ebc.selectedIds', []);
  };
  
  function clearGrids() {
    eventData.setItems([]);
    attendeeData.setItems([]);
    resultData.setItems([]);
  };
  
  function renderEvent(row, cell, value, columnDef, dataContext) {
    return eventTemplate(dataContext);
  };
  
  function filterItem(item, args) {
    if (args.searchTerm != "") {
      var text = '';
      for (var c = 0; c < args.searchCols.length; c++) {
        text += ' ' + item[args.searchCols[c]].toLowerCase();
      }
      var terms = args.searchTerm.toLowerCase().split(' ');
      for (var i = 0; i < terms.length; i++) {
        if (text.indexOf(terms[i]) == -1) return false;
      }
    }
    return true;
  };
  
  function salesforeDateFormatter(row, cell, value, columnDef, dataContext) {
    if (value) {
      return $.datepicker.formatDate('mm/dd/yy', new Date(value));
    }
  };
  
  function formatEventbriteDate(dateString) {
    var dateParts = dateString.split(' ')[0].split('-');
    return $.datepicker.formatDate('mm/dd/yy', new Date(dateParts[0], dateParts[1] - 1, dateParts[2]));
  };
  
  function updateSelectedEvent() {
    var selectedEvent = getSelectedItem(eventContainer, eventData);
    if (selectedEvent) {
      attendeeData.setItems([]);
      attendeeContainer.addClass('grid-loading');
      eventButton.button('disable');
      attendeeData.beginUpdate();
      
      // Update new campaign details.
      campaignNewName.val(selectedEvent.title);
      contactDescription.val('Imported from Eventbrite event "' + selectedEvent.title + '"');
      
      var descriptionText = $('<div></div>').html(selectedEvent.description || '').text(),
        start = null,
        end = null;
      if (descriptionText.length > 0) descriptionText += '\n\n';
      
      if (selectedEvent.start_date) {
        start = formatEventbriteDate(selectedEvent.start_date);
        campaignNewStart.val(start);
        descriptionText += start;
      }
      if (selectedEvent.end_date) {
        end = formatEventbriteDate(selectedEvent.end_date);
        campaignNewEnd.val(end);
        if (start !== end) descriptionText += ' - ' + end;
      }
      
      campaignNewDescription.val(descriptionText);

      freeEvent = true;
      populateAttendeeList(selectedEvent.id, 1);
    }
  };
  
  function populateAttendeeList(eventId, attendeePage) {
    // Query for attendees.
    ebClient.event_list_attendees({
      id: eventId,
      count: 100,
      page: attendeePage,
      do_not_display: 'profile'
    }, function(response) {
      if (handleEventbriteError(response)) {
        
        $.each(response.attendees, function() {
          attendeeData.addItem(this.attendee);
          if (this.attendee.amount_paid > 0) {
            freeEvent = false;
          }
        });
        
        if (response.attendees.length < 100) {
          attendeeContainer.removeClass('grid-loading');
          attendeeData.endUpdate();
          // Select all attendees by default.
          var rows = [];
          for (var i = 0; i < attendeeData.getLength(); i++) {
            rows.push(i);
          }
          resetSelectionCache(attendeeContainer);
          attendeeGrid.setSelectedRows(rows);
          if (freeEvent) {
            importActionContactsOpps.button('disable');
            if (importAction.filter(':checked').val() === 'contacts-opps') {
              importActionContacts.click();
            }
          } else {
            importActionContactsOpps.button('enable');
          }
        } else {
          populateAttendeeList(eventId, attendeePage + 1);
        }
      }
    });
  };
  
  function updateSelectedAttendees() {
    var selectedCount = attendeeContainer.data('ebc.selectedIds').length;
    if (selectedCount) {
      eventButton.button('enable');
      eventStatus.text('Selected ' + selectedCount + ' of ' + attendeeData.getItems().length + ' for import.');
    } else {
      eventButton.button('disable');
      eventStatus.text('Please select attendees to import.');
    }
  };
  
  function updateSelectedCampaign() {
    var selectedCampaign = getSelectedItem(campaignContainer, campaignData);
    if (selectedCampaign) {
      updateCampaignMemberStatusList(selectedCampaign.Id);
      // Update the tab status.
      campaignStatus.text('Selected "' + selectedCampaign.Name + '".');
      // Enable the continue button.
      campaignButton.button('enable');
    }
  };
  
  function updateCampaignMemberStatusList(campaignId) {
    campaignMemberStatus.empty().addClass('hidden-select');
    campaignMemberStatusLabel.addClass('label-loading');
    if (campaignMemberStatusCache[campaignId] !== undefined) {
      populateCampaignMemberStatusList(campaignMemberStatusCache[campaignId]);
    } else {
      gweb.EventbriteImportController.getCampaignMemberStatuses(campaignId, function(result, e) {
        if (handleSalesforceError(e)) {
          campaignMemberStatusCache[campaignId] = result;
          populateCampaignMemberStatusList(result);
        }
      }, {escape: false});
    }
  };
  
  function populateCampaignMemberStatusList(statuses) {
    $.each(statuses, function(i, status) {
      $('<option></option>').attr('value', status).text(status)
        .appendTo(campaignMemberStatus);
    });
    if (settings['gweb__Campaign_Member_Status__c'] !== undefined) {
      campaignMemberStatus.val(settings['gweb__Campaign_Member_Status__c']);
    }
    campaignMemberStatus.change();
    campaignMemberStatusLabel.removeClass('label-loading');
    campaignMemberStatus.removeClass('hidden-select');
  };
  
  function formatResultName(row, cell, value, columnDef, dataContext) {
    return linkTemplate({
      text: value,
      title: null,
      url: dataContext.link || null,
      cssClass: 'normal'
    });
  };
  
  function formatResultOpp(row, cell, value, columnDef, dataContext) {
    return linkTemplate({
      text: dataContext.opportunityName || null,
      title: null,
      url: dataContext.opportunityLink || null,
      cssClass: 'normal'
    });
  };
  
  function formatResultSummary(row, cell, value, columnDef, dataContext) {
    return linkTemplate({
      text: (dataContext.errorMessage) ? 'Error' : 'Success',
      title: dataContext.errorMessage || dataContext.summary,
      url: null,
      cssClass: ((dataContext.summary === 'Error') ? 'error' : 'success') + ' summary-hover'
    });
  };
  
  function getResultColumns(showOpps) {
    if (showOpps) {
      return resultColumns;
    } else {
      var columns = resultColumns.slice(0, 2);
      columns.push(resultColumns[3])
      return columns;
    }
  };
  
  function setImportTypeText(importType) {
    importTypeText.text(importType).filter('.lower').text(importType.toLowerCase());
  };
  
  /* Accessors */
  
  function getSelectedItem(el, data) {
    var selectedIds = el.data('ebc.selectedIds');
    if (selectedIds.length) {
      return data.getItemById(selectedIds[0]);
    }
  };
  
  function getSelectedItems(el, data, batchSize, stringify) {
    var selectedIds = el.data('ebc.selectedIds');
    var rows = [],
      items = [];
    $.each(selectedIds, function(i, itemId) {
      if (stringify) {
        items.push(JSON.stringify(data.getItemById(itemId)));
      } else {
        items.push(data.getItemById(itemId));
      }
      if (items.length === batchSize) {
        rows.push(items);
        items = [];
      }
    });
    if (items.length) {
      rows.push(items);
    }
    return rows;
  };
  
  /* Salesforce */
  
  function dateForSF(dateStr) {
    if (dateStr === '') {
      return null;
    }
    return new Date(dateStr).toUTCString();
  };
  
  /* Campaign Creation */
  
  function validateCampaignInput() {
    campaignNewName.add(campaignNewStart, campaignNewEnd).removeClass('ui-state-error');
    if (!campaignNewName.val()) {
      campaignNewName.addClass('ui-state-error');
      return false;
    }
    var start = new Date(campaignNewStart.val()),
      end = new Date(campaignNewEnd.val());
    if (campaignNewStart.val() && !isFinite(start)) {
      campaignNewStart.addClass('ui-state-error');
      return false;
    }
    if (campaignNewEnd.val() && !isFinite(end)) {
      campaignNewEnd.addClass('ui-state-error');
      return false;
    }
    if (campaignNewStart.val() && campaignNewEnd.val()) {
      if (end < start) {
        campaignNewStart.add(campaignNewEnd).addClass('ui-state-error');
        return false;
      }
    }
    return true;
  };
  
  function extractCampaignArguments(callback) {
    var parentId = campaignNewParent.val();
    if (parentId === '000000000000000') parentId = null;
    return [
      campaignNewName.val(),
      campaignNewRecordType.filter(':checked').val() || null,
      campaignNewType.val() || null,
      dateForSF(campaignNewStart.val()),
      dateForSF(campaignNewEnd.val()),
      campaignNewStatus.val() || null,
      parentId,
      campaignNewDescription.val(),
      callback
    ];
  };
  
  function createCampaignData(response) {
    return {
      Id: response.campaignId,
      IsActive: true,
      LastModifiedDate: new Date().getTime(),
      Name: campaignNewName.val(),
      StartDate: new Date(campaignNewStart.val()).getTime(),
      Status: campaignNewStatus.val(),
      Type: campaignNewType.val(),
      id: response.campaignId
    }
  };
    
  /* Event Grid */
  eventGrid.setSelectionModel(new Slick.RowSelectionModel());
  initializeGrid(eventContainer, eventGrid, eventData, {
    sortable: false, 
    searchable: true, 
    searchCols: ['title'], 
    searchInput: $('#events-search'), 
    selectCallback: updateSelectedEvent
  });
  
  $('#events-sort').change(function() {
    var asc = $(this).val() != 'start_date';
    eventData.fastSort($(this).val(), asc);
  });
  
  /* Attendee Grid */

  attendeeGrid.setSelectionModel(new Slick.RowSelectionModel({selectActiveRow:false}));
  attendeeGrid.registerPlugin(attendeeSelector);
  initializeGrid(attendeeContainer, attendeeGrid, attendeeData, {
    sortable: true, 
    searchable: true, 
    searchCols: ['first_name', 'last_name', 'email'], 
    selectCallback: updateSelectedAttendees,
    paginate: true
  });
  
  /* Campaign Grid */
  
  campaignGrid.setSelectionModel(new Slick.RowSelectionModel());
  initializeGrid(campaignContainer, campaignGrid, campaignData, {
    sortable: true,
    paginate: true,
    searchable: true, 
    searchCols: ['Name', 'Type']
  });
  campaignGrid.onSelectedRowsChanged.subscribe(updateSelectedCampaign);
  
  gweb.EventbriteImportController.getCampaignList(options.campaignBatch, function(result, e) {
    if (handleSalesforceError(e)) {
      $.each(result, function() {
        this['id'] = this.Id;
      });
            
      campaignData.beginUpdate();
      campaignData.setItems(result);
      campaignData.endUpdate();
    }
  }, {escape: false});
  
  /* Result Grid */
  
  initializeGrid(resultContainer, resultGrid, resultData, {
    sortable: true,
    searchable: true, 
    searchCols: ['firstname', 'lastname'],
    paginate: true
  });
  
  /* Campaign tab */
  eventButton.click(function() {
    tabs.tabs('option', 'disabled', [3, 4]).tabs('select', 2);
  });
  campaignAction.change(function() {
    var action = campaignAction.filter(':checked').val();
    var wrappers = $('.campaign-wrapper').hide();
    if (action === 'existing') {
      wrappers.filter('#campaign-existing-wrapper').show();
      updateSelectedCampaign();
    } else if (action === 'new') {
      wrappers.filter('#campaign-new-wrapper').show();
      campaignButton.button('disable');
      campaignStatus.text('No ' +  options.labels.campaign.toLowerCase() + ' selected.');
    } else if (action === 'none') {
      wrappers.filter('#campaign-none-wrapper').show();
      campaignButton.button('enable');
      campaignStatus.text('No ' +  options.labels.campaign.toLowerCase() + ' selected.');
    }
  });
  
  // Campaign creation
  campaignNewButton.click(function() {
    newCampaign.dialog('open');
  });
  
  /* Import tab */
  campaignButton.click(function() {
    tabs.tabs('option', 'disabled', [4]).tabs('select', 3);
    importAction.change();
  });
  importAction.change(function(e) {
    var action = importAction.filter(':checked').val(),
      elements = $('.import-leads, .import-contacts, .import-contacts-opps').hide(),
      statusText = 'Importing ',
      selectedEvent = getSelectedItem(eventContainer, eventData);
    
    if (selectedEvent) {
      statusText += attendeeContainer.data('ebc.selectedIds').length;
      statusText += ' attendees from ' + selectedEvent.title;
    }
    
    if (action) {
      elements.filter('.import-' + action).show();
      importButton.button('enable');
    }
    if (action === 'leads') {
      importStatus.text(statusText + ' as ' + options.labels.leadPlural.toLowerCase() + '.');
      setImportTypeText(options.labels.lead);
    } else if (action === 'contacts') {
      importStatus.text(statusText + ' as ' + options.labels.contactPlural.toLowerCase() + '.');
      setImportTypeText(options.labels.contact);
    } else if (action === 'contacts-opps') {
      importStatus.text(statusText + ' as ' + options.labels.contactPlural.toLowerCase() + ' and ' + options.labels.oppPlural.toLowerCase() + '.');
      setImportTypeText(options.labels.contact);
    }
  });
  
  // Import dialog.
  importProgress.bind('dialogclose', function(e, ui) {
    // Tell the result grid to update itself.
    resultData.endUpdate();
    // Show the results tab.
    tabs.tabs('option', 'disabled', []).tabs('select', 4);
    // Show a message if we hit an error.
    if (importError) {
      errorMessages.filter('#error-import').dialog('open');
    }
  });
  
  // Perform the import.
  importButton.click(function() {
            
    // Show a dialog with a progress bar.
    importProgress.dialog('open');
    
    var attendeeBatches = getSelectedItems(attendeeContainer, attendeeData, options.importBatch, true),
      numBatches = attendeeBatches.length,
      eventJSON = JSON.stringify(getSelectedItem(eventContainer, eventData)),
      selectedCampaign = getSelectedItem(campaignContainer, campaignData),
      campaignId = (selectedCampaign) ? selectedCampaign.Id : null,
      contactDescriptionValue = contactDescription.val() || null;
      
    importError = false;
        
    importIndicator.progressbar('value', 0);
    // If we only have one batch, we use a full bar.
    if (numBatches === 1) {
      importIndicator.progressbar('value', 100);
    }
    
    resultData.beginUpdate();
    resultData.setItems([]);
    $.each(attendeeBatches, function(i, attendees) {
      if (!importProgress.dialog('isOpen')) {
        return false;
      }
      gweb.EventbriteImportController.importAttendees.apply(gweb.EventbriteImportController, getImportArgs(eventJSON, attendees, campaignId, contactDescriptionValue, function(result, e) {
          if (handleSalesforceError(e)) {
            // Update the progress bar.
            importIndicator.progressbar('value', 100 * (i + 1) / numBatches);
            // Populate the results grid.
            $.each(result, function(resultNum, item) {
              this['id'] = i * options.importBatch + resultNum;
              resultData.addItem(this);
              importError = (this.errorMessage !== undefined);
            });
            // Check whether we're done.
            if (i + 1 === numBatches) {
              importProgress.dialog('close');
            }
          }
        }));
    });
    resultGrid.setColumns(getResultColumns(settings.gweb__Option_for_Leads_or_Contacts__c === 2));
  });
  
  /* Authentication */
  userkeyWhat.click(function(e) {
    aboutUserkey.dialog('open');
    e.preventDefault();
  });
  
  $('#authenticate').button().click(function() {
    if (!((settings['gweb__Username__c'] && settings['gweb__Password__c']) || settings['gweb__API_User_Key__c'])) {
      errorMessages.filter('#error-invalidemailaddressnone').dialog('open');
    } else {
      Eventbrite({
        'app_key': options.apiKey,
        'user_key': userkey.val(),
        'user': email.val(),
        'password': password.val()
      }, function(client) {
        ebClient = client;
        /* List events */
        ebClient.user_list_events({
          do_not_display: 'venue,logo,style,organizer',
          asc_or_desc: 'desc'
        }, function(response) {
          if (handleEventbriteError(response)) {
            clearGrids();
            // Populate the events grid.
            eventData.beginUpdate();
            $.each(response.events, function() {
              eventData.addItem(this.event);
            });
            eventData.endUpdate();
            tabs.tabs('option', 'disabled', [2, 3, 4]).tabs('select', 1);
          }
        });
      });
    }
  });
  
  /* Initialize settings */
  simpleSetting(userkey, 'gweb__API_User_Key__c');
  simpleSetting(email, 'gweb__Username__c');
  simpleSetting(password, 'gweb__Password__c');
  rememberSetting(remember, 'gweb__Password__c');
  
  radioIndexSetting(campaignAction, 'gweb__Option_for_Campaign__c');
  radioValueSetting(campaignNewRecordType, 'gweb__Campaign_Record_Type_for_New_Campaigns__c');
  simpleSetting(campaignNewType, 'gweb__Campaign_Type_for_New_Campaigns__c');
  simpleSetting(campaignNewStatus, 'gweb__Campaign_Status__c');
  simpleSetting(campaignMemberStatus, 'gweb__Campaign_Member_Status__c');
  
  radioIndexSetting(importAction, 'gweb__Option_for_Leads_or_Contacts__c');
  checkboxSetting(matchContacts, 'gweb__Use_Existing_Contact__c');
  checkboxSetting(importCreateAccounts, 'gweb__Create_Accounts__c');
  radioBoolSetting(importOverwriteContacts, 'gweb__Overwrite_Contact_Detail__c');
  simpleSetting(leadSource, 'gweb__Lead_Source__c');
  simpleSetting(oppStage, 'gweb__Opp_Stage__c');
  simpleSetting(oppContactRole, 'gweb__Opp_Contact_Role__c');
  radioValueSetting(oppRecordType, 'gweb__Opp_Record_Type_Id__c');
  
  /* Show time! */
  container.show();
};
