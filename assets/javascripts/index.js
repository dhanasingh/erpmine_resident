var apartmentUrl, residentUrl, performserviceUrl;

$(document).ready(function()
{
	changeProp('tab-rmapartment',apartmentUrl);
	changeProp('tab-rmresident',residentUrl);
	changeProp('tab-rmperformservice',performserviceUrl);
	
	var url_string = window.location.href;
	var url = new URL(url_string);
	var res_action = url.searchParams.get("res_action");
	if(res_action && res_action != 'MO'){
		apartmentBasedBeds('apartment_idM', 'bed_idM', 1, 'rateM', 'lblBedM', true );
	}
	$('#res_contact').hide();
	});

function changeProp(tab,indexUrl)
{
	var tab_te = document.getElementById(tab);
	var tabName = tab.split('-');
	if(tab_te != null)
	{
		tab_te.href = indexUrl;
		tab_te.onclick = function(){
			var load = false;
			if(prevTab != (this.id).toString())
			{
				load = true;
			}			
			prevTab = this.id;
			return load;
		};
	}
}

function locationbasedApartment(locationId, apartmentId, uid, bedId, bedLbl, rateId, resMoveIn)
{
	locVal = document.getElementById(locationId).value;
	var loadDropdown = document.getElementById(apartmentId);	
	var needBlankOption = false;
	userid = uid;
	var $this = $(this);
	$.ajax({
	url: locationUrl,
	type: 'get',
	data: {location_id: locVal, resMoveIn: resMoveIn},
	success: function(data){ updateUserDD(data, loadDropdown, userid, needBlankOption, false, "");},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ apartmentBasedBeds(apartmentId, bedId, uid, rateId, bedLbl, resMoveIn); $this.removeClass('ajax-loading');  }	   
	});
}

function apartmentBasedBeds(apartmentId, bedId, uid, rateId, bedLbl, resMoveIn)
{
	aprVal = document.getElementById(apartmentId).value;
	var loadDropdown = document.getElementById(bedId);	
	var needBlankOption = false;
	userid = uid;
	var $this = $(this);
	$.ajax({
	url: bedUrl,
	type: 'get',
	data: {apartment_id: aprVal, resMoveIn: resMoveIn},
	success: function(data){
		if(data != "") {
			showorHide(true, bedLbl, bedId);
			updateUserDD(data, loadDropdown, userid, needBlankOption, false, "");
		} 
		else {
			$('#'+ bedId +' option').remove();
			showorHide(false, bedLbl, bedId); 
		} 
	},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ bedsLogRate(bedId, rateId, 'move_in_rate_perM', apartmentId); $this.removeClass('ajax-loading'); }	   
	});
}

function bedsLogRate(bedId, rateId, rateperId, apartmentId)
{
	bedVal = document.getElementById(bedId).value;
	apartmentVal = document.getElementById(apartmentId).value;
		
	var $this = $(this);
	$.ajax({
	url: bedRateUrl,
	type: 'get',
	data: {bed_id: bedVal, apartment_id: apartmentVal},
	success: function(data){ setLogRate(data, rateId, rateperId);  },
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ $this.removeClass('ajax-loading'); }	   
	});
}

function setLogRate(rateArr, rateId, rateperId)
{
	logValue = rateArr.split(',');
	document.getElementById(rateperId).innerHTML = (logValue[0] == null || logValue[0] == "") ? "" : logValue[0];
	document.getElementById(rateId).value = (logValue[1] == null || logValue[1] == "") ? "" : logValue[1];
}

function dateRangeValidation(fromId, toId)
{	
	var fromElement = document.getElementById(fromId);
	var toElement = document.getElementById(toId);
	var fromdate = new Date(fromElement.value);
	var todate = new Date(toElement.value);
	var d = new Date();
	if(fromdate > todate)
	{
		fromElement.value = fromElement.defaultValue;
		d.setDate(fromdate.getDate()+30);
		d.setMonth(d.getMonth()+1);
		toElement.value = d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate();
		alert(" End date should be greater then start date ");
	}
	
}

function residentType(){
	var residentType = $('#resident_type').val();
	if(residentType == 'WkAccount'){
		$('#res_contact').hide();
		$('#res_account').show();
	}
	else{
		$('#res_contact').show();
		$('#res_account').hide();
	}
}