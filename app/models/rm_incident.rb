# ERPmine - ERP for service industry
# Copyright (C) 2011-2020  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class RmIncident < ApplicationRecord
	include Redmine::SafeAttributes

	INCIDENT_ENUM_TYPE = 'RIT'.freeze
	STATUS_OPEN = 'O'.freeze
	STATUS_CLOSED = 'C'.freeze

	belongs_to :rm_resident, :class_name => 'RmResident', :foreign_key => 'rm_resident_id'
	belongs_to :created_user, :class_name => 'User', :foreign_key => 'created_by_user_id'
	belongs_to :updated_user, :class_name => 'User', :foreign_key => 'updated_by_user_id'
	has_many :wkstatus, -> { where(status_for_type: 'RmIncident') },
		:foreign_key => 'status_for_id', :class_name => 'WkStatus', :dependent => :destroy

	validates_presence_of :rm_resident_id, :incident_datetime, :status
	validates_inclusion_of :status, :in => [STATUS_OPEN, STATUS_CLOSED]
	validate :incident_type_enum_link
	before_validation :normalize_status_value

	safe_attributes 'rm_resident_id', 'incident_datetime', 'incident_type_id', 'desc',
		'location', 'witnesses', 'imm_action', 'injuries',
		'notes', 'follow_up', 'prev_action',
		'rpt_name',
		'status', 'created_by_user_id', 'updated_by_user_id'

	private

	def normalize_status_value
		case status.to_s.strip.downcase
		when '', 'open', STATUS_OPEN.downcase
			self.status = STATUS_OPEN
		when 'closed', STATUS_CLOSED.downcase
			self.status = STATUS_CLOSED
		end
	end

	def incident_type_enum_link
		return if incident_type_id.blank?

		enum_exists = WkCrmEnumeration.where(id: incident_type_id, enum_type: INCIDENT_ENUM_TYPE).exists?
		errors.add(:incident_type_id, :invalid) unless enum_exists
	end
end
