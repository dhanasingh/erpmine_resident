(function() {
  function initializeIncidentDateTime(form) {
    if (form.dataset.incidentNewRecord !== 'true') {
      return;
    }

    var dateTimeInput = document.getElementById('incident_incident_datetime');
    if (!dateTimeInput || dateTimeInput.value) {
      return;
    }

    var now = new Date();
    var pad = function(value) { return String(value).padStart(2, '0'); };
    var localDateTime = now.getFullYear() + '-' +
      pad(now.getMonth() + 1) + '-' +
      pad(now.getDate()) + 'T' +
      pad(now.getHours()) + ':' +
      pad(now.getMinutes());

    dateTimeInput.value = localDateTime;
  }

  function initializeResidentSection(form) {
    if (form.dataset.residentDynamic !== 'true') {
      return;
    }

    var residentSelect = document.getElementById('incident_rm_resident_id');
    var locationSelect = document.getElementById('incident_resident_location');
    var apartmentInfo = document.getElementById('incident_resident_apartment');
    var bedInfo = document.getElementById('incident_resident_bed');
    var moveInInfo = document.getElementById('incident_resident_move_in');
    var locationInfo = document.getElementById('incident_resident_location_info');
    var infoUrl = form.dataset.residentInfoUrl;
    var filterUrl = form.dataset.residentsByLocationUrl;

    if (!residentSelect || !locationSelect || !infoUrl || !filterUrl) {
      return;
    }

    function updateResidentInfo() {
      var selectedId = residentSelect.value;
      if (!selectedId) {
        apartmentInfo.textContent = '-';
        bedInfo.textContent = '-';
        moveInInfo.textContent = '-';
        locationInfo.textContent = '-';
        return;
      }

      fetch(infoUrl + '?rm_resident_id=' + encodeURIComponent(selectedId), { headers: { 'Accept': 'application/json' } })
        .then(function(resp) { return resp.json(); })
        .then(function(data) {
          apartmentInfo.textContent = data.apartment || '-';
          bedInfo.textContent = data.bed || '-';
          moveInInfo.textContent = data.move_in_date || '-';
          locationInfo.textContent = data.location || '-';
        });
    }

    function rebuildResidents() {
      var currentSelectedId = residentSelect.value;
      var locationFilter = locationSelect.value;

      fetch(filterUrl + '?location_id=' + encodeURIComponent(locationFilter), { headers: { 'Accept': 'application/json' } })
        .then(function(resp) { return resp.json(); })
        .then(function(residents) {
          residentSelect.innerHTML = '';

          residents.forEach(function(entry) {
            var option = document.createElement('option');
            option.value = entry.id;
            option.text = entry.name;
            residentSelect.appendChild(option);
          });

          var hasCurrentSelection = residents.some(function(entry) { return String(entry.id) === String(currentSelectedId); });
          residentSelect.value = hasCurrentSelection ? currentSelectedId : (residents[0] ? String(residents[0].id) : '');
          updateResidentInfo();
        });
    }

    locationSelect.addEventListener('change', rebuildResidents);
    residentSelect.addEventListener('change', updateResidentInfo);
    rebuildResidents();
  }

  document.addEventListener('DOMContentLoaded', function() {
    var form = document.getElementById('incident_form');
    if (!form) {
      return;
    }

    initializeIncidentDateTime(form);
    initializeResidentSection(form);
  });
})();
