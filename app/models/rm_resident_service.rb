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

class RmResidentService < ApplicationRecord
  include Redmine::SafeAttributes
  # attr_protected :others
  belongs_to :resident, :class_name => 'RmResident', :foreign_key => 'rm_resident_id'
  belongs_to :issue
  belongs_to :created_user, :class_name => 'User', :foreign_key => 'created_by_user_id'
  belongs_to :updated_user, :class_name => 'User', :foreign_key => 'updated_by_user_id'
  validates_presence_of :start_date, :issue_id,  :rm_resident_id
  safe_attributes 	'rm_resident_id','issue_id', 'start_date', 'end_date', 'frequency', 'no_of_occurrence', 'created_by_user_id', 'updated_by_user_id'

  validate :end_date_is_after_start_date

	def end_date_is_after_start_date

		unless start_date.blank?
			if !end_date.blank?
				if end_date < start_date
					errors.add(:end_date, "cannot be before the start date")
				end
			end

			currentRes = self.resident
			if currentRes.move_out_date.present?
				errors.add(:invalid, "Could not add Service and Amenities for Former residents")
			else
				if !end_date.blank? && !currentRes.move_out_date.blank? && currentRes.move_out_date.to_date < end_date
					errors.add(:end_date, "cannot be after the move out date")
				end
				if currentRes.move_in_date.to_date > start_date
					errors.add(:start_date, "cannot be before the move in date")
				end
			end
		end
	end
end