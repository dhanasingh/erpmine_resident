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

module RmevaluationHelper
	include RmresidentHelper

	def getResidents
		resident = Array.new
		entries = RmResident.left_join_contacts.where("rm_residents.move_out_date IS NULL").order(id: :desc)
														.select("rm_residents.id, wk_accounts.name as account_name, first_name, last_name, resident_type")
		# Restrict the "Select Resident" dropdown to the user's permitted location
		# subtree, matching the evaluation list. nil ids => unrestricted => no-op.
		entries = WkLocation.filter_by_contact_account_location(entries, WkLocation.accessible_location_ids)
		(entries || []).each do  |r|
			residentName = r.resident_type == "WkAccount" ? r.account_name : ((r&.first_name || '') + ' ' + (r&.last_name || ''))
			resident <<  [residentName, r.id  ]
		end
		resident.unshift(["",0])
	end
	
	def getEvaluationList
		evaluations = []

		surveyList = WkSurvey.where(survey_for_type: 'RmResident').order(id: :desc)

		surveyList.each do |s|
			evaluations << [s.name, s.id]
		end

		evaluations
	end
end
