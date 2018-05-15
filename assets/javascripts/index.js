var apartmentUrl, residentUrl, performserviceUrl;

$(document).ready(function()
{
	changeProp('tab-rmapartment',apartmentUrl);
	changeProp('tab-rmresident',residentUrl);
	changeProp('tab-rmperformservice',performserviceUrl);
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

function locationbasedApartment(locationId, apartmentId, uid, bedId, bedLbl, rateId)
{
	locVal = document.getElementById(locationId).value;
	var loadDropdown = document.getElementById(apartmentId);	
	var needBlankOption = false;
	userid = uid;
	var $this = $(this);
	$.ajax({
	url: locationUrl,
	type: 'get',
	data: {location_id: locVal},
	success: function(data){ updateUserDD(data, loadDropdown, userid, needBlankOption, false, "");},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ apartmentBasedBeds(apartmentId, bedId, uid, rateId, bedLbl); $this.removeClass('ajax-loading');  }	   
	});
}

function apartmentBasedBeds(apartmentId, bedId, uid, rateId, bedLbl)
{
	aprVal = document.getElementById(apartmentId).value;
	var loadDropdown = document.getElementById(bedId);	
	var needBlankOption = false;
	userid = uid;
	var $this = $(this);
	$.ajax({
	url: bedUrl,
	type: 'get',
	data: {apartment_id: aprVal},
	success: function(data){ if(data != "") { showorHide(true, bedLbl, bedId); updateUserDD(data, loadDropdown, userid, needBlankOption, false, "");} else { showorHide(false, bedLbl, bedId); } },
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ bedsLogRate(bedId, rateId, 'move_in_rate_per', apartmentId); $this.removeClass('ajax-loading'); }	   
	});
}

function bedsLogRate(bedId, rateId, rateperId, apartmentId)
{
	bedVal = document.getElementById(bedId).value;
	apartmentVal = document.getElementById(apartmentId).value;
	if(bedVal == "")
	{
		bedVal = apartmentVal;
	}	
	var $this = $(this);
	$.ajax({
	url: bedRateUrl,
	type: 'get',
	data: {bed_id: bedVal},
	success: function(data){ setLogRate(data, rateId, rateperId);  },
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ $this.removeClass('ajax-loading'); }	   
	});
}

function setLogRate(rateArr, rateId, rateperId)
{
	logValue = rateArr.split(',');
	document.getElementById(rateperId).innerHTML = logValue[0];
	document.getElementById(rateId).value = logValue[1] == "" ? "" : logValue[1];
}