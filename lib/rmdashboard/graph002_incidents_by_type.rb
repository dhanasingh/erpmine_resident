module Rmdashboard
  module Graph002IncidentsByType
    include RmincidentHelper

    def chart_data(param={})
      data = {
        graphName: l(:label_incidents_by_type), chart_type: "doughnut", xTitle: l(:field_incident_type), yTitle: l(:label_incident),
        legentTitle1: l(:label_total_incidents)
      }
      entries = getIncidents(param)
      entries = entries.joins("LEFT JOIN wk_crm_enumerations ON wk_crm_enumerations.id = rm_incidents.incident_type_id")
        .group("rm_incidents.incident_type_id,wk_crm_enumerations.name")
        .select("rm_incidents.incident_type_id, COALESCE(wk_crm_enumerations.name, '#{l(:label_none)}') as type_name, COUNT(*) as incident_count")
      incidents = entries.map{|c| [c.type_name, c.incident_count]}.to_h
      data[:fields] = incidents.keys
      data[:data1] = incidents.values
      return data
    end

    def get_detail_report(param={})
      entries = getIncidents(param).order("incident_date DESC")
        .joins("LEFT JOIN wk_crm_enumerations ON wk_crm_enumerations.id = rm_incidents.incident_type_id")
      header = {resident: l(:label_resident), incident_type: l(:field_incident_type), date: l(:field_incident_date), location: l(:field_location), status: l(:field_status)}
      data = entries.map{|e| {
        resident: e&.rm_resident&.name,
        incident_type: e.incident_type_id.present? ? WkCrmEnumeration.find_by(id: e.incident_type_id)&.name : '',
        date: e&.incident_date&.to_date,
        location: e&.location,
        status: incident_status_label(e.workflow_status_code)
      }}
      return {header: header, data: data}
    end

    private

    def getIncidents(param={})
      entries = RmIncident.where("incident_date BETWEEN ? AND ?", param[:from].beginning_of_day, param[:to].end_of_day)
      location_name = WkLocation.find_by(id: param[:location_id])&.name
      entries = entries.where(location: location_name) if location_name.present?

      entries
    end

  end
end
