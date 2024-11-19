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

class RmperformserviceController < WktimeController

	menu_item	:apartment


	def index
		redirect_to action: :edit, user_id: User.current.id, sheet_view: getSheetView()
	end

	def getSheetView
		"I"
	end

	def hideprevTemplate
		true
	end

	def getCondition(date_field, user_id, start_date, end_date=nil)
		trackerId = Setting.plugin_erpmine_resident['rm_service_tracker']
		@renderer.issue_join_cond = " and i.tracker_id = #{trackerId}" if trackerId.present?
		@renderer.spent_for_join = " left join rm_residents rm on ( ap.parent_type = rm.resident_type and ap.parent_id = rm.resident_id ) inner join rm_resident_services rs on (i.id = rs.issue_id and rs.rm_resident_id = rm.id)"
		@renderer.spent_for_cond = " and (rs.end_date is null or rs.end_date >= '#{start_date}')"
		# cond = " and i.tracker_id = #{trackerId}"
		super
	end

	def showProjectDD
		false
	end

	def getDefultProject
		Setting.plugin_erpmine_resident['rm_project'] #get from settings
	end

	def showActivityDD
		false
	end

	def getDefultActivity
		activityObj = Enumeration.where(:type => 'TimeEntryActivity')
		activityId = activityObj.blank? ? 0 : activityObj[0].id
		activityId #get from settings
	end

	def set_loggable_projects
			Rails.logger.info("======== perform service controller ================")
			@logtime_projects = Project.where(:id => getDefultProject)
			@logtime_projects = setTEProjects(@logtime_projects)
			@edit_own_logs = Project.where(Project.allowed_to_condition(User.current, :edit_own_time_entries)).order('name')
	end

	def set_managed_projects
		# from version 1.7, the project member with 'edit time logs' permission is considered as managers
		# mng_projects = call_hook(:controller_set_manage_projects)
		# if !mng_projects.blank?
			# @manage_projects = mng_projects[0].blank? ? nil : mng_projects[0]
		# else
			# if isAccountUser
				# @manage_projects = getAccountUserProjects
			# else
				# @manage_projects ||= Project.where(Project.allowed_to_condition(User.current, :edit_time_entries)).order('name')
			# end
		# end
		@manage_projects =	Project.where(:id => getDefultProject)

		# @manage_view_spenttime_projects contains project list of current user with edit_time_entries and view_time_entries permission
		# @manage_view_spenttime_projects is used to fill up the dropdown in list page for managers
		view_projects = call_hook(:controller_set_view_projects)
		if !view_projects.blank?
			@manage_view_spenttime_projects = view_projects[0].blank? ? nil : view_projects[0]
		else
			if validateERPPermission('A_TE_PRVLG')
				@manage_view_spenttime_projects = getAccountUserProjects
			else
				@view_spenttime_projects ||= Project.where(Project.allowed_to_condition(User.current, :view_time_entries)).order('name')
				@manage_view_spenttime_projects = @manage_projects & @view_spenttime_projects
			end
		end
		@manage_view_spenttime_projects = setTEProjects(@manage_view_spenttime_projects)

		# @currentUser_loggable_projects contains project list of current user with log_time permission
		# @currentUser_loggable_projects is used to show/hide new time & expense sheet link
		@currentUser_loggable_projects ||= Project.where(Project.allowed_to_condition(User.current, :log_time)).order('name')
		@currentUser_loggable_projects = setTEProjects(@currentUser_loggable_projects)
	end

	def filterTrackerVisible
		false
	end

	def hasApprovalSystem
		false
	end

	def getEntityLabel
		l(:label_perform_service)
	end

	def getLblIssue
		l(:label_service)
	end

	def getLblSpentFor
		l(:label_service_for)
	end

	def getTFSettingName
		"wkexpense_issues_filter_tracker"
	end

	def getLblSpentOn
		l(:field_spent_on)
	end

  def showAttachments
    false
  end
end
