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
	STATUS_NEW = 'N'.freeze
	STATUS_SUBMITTED = 'S'.freeze
	STATUS_APPROVED = 'A'.freeze

	belongs_to :rm_resident, :class_name => 'RmResident', :foreign_key => 'rm_resident_id'
	belongs_to :created_user, :class_name => 'User', :foreign_key => 'created_by_user_id'
	belongs_to :updated_user, :class_name => 'User', :foreign_key => 'updated_by_user_id'
	has_many :wkstatus, -> { where(status_for_type: 'RmIncident') },
		:foreign_key => 'status_for_id', :class_name => 'WkStatus', :dependent => :destroy

	validates_presence_of :rm_resident_id, :incident_datetime
	validate :incident_type_enum_link

	safe_attributes 'rm_resident_id', 'incident_datetime', 'incident_type_id', 'desc',
		'location', 'witnesses', 'imm_action', 'injuries',
		'notes', 'follow_up', 'prev_action',
		'rpt_name',
		'created_by_user_id', 'updated_by_user_id'

	def workflow_status_code
		return STATUS_NEW if new_record?

		return STATUS_APPROVED if wkstatus.where(status: STATUS_APPROVED).exists?
		return STATUS_SUBMITTED if wkstatus.where(status: STATUS_SUBMITTED).exists?

		STATUS_NEW
	end

	private

	def incident_type_enum_link
		return if incident_type_id.blank?

		enum_exists = WkCrmEnumeration.where(id: incident_type_id, enum_type: INCIDENT_ENUM_TYPE).exists?
		errors.add(:incident_type_id, :invalid) unless enum_exists
	end
end
