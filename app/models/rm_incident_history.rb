class RmIncidentHistory < ApplicationRecord
	self.table_name = 'rm_incident_logs'

	belongs_to :rm_incident, :class_name => 'RmIncident', :foreign_key => 'rm_incident_id'
	belongs_to :action_user, :class_name => 'User', :foreign_key => 'action_by_id', optional: true

	validates_presence_of :rm_incident_id, :action_type, :action_on
	validates_inclusion_of :action_type, in: ['U', 'D']
end
