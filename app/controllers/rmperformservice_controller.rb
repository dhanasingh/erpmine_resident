class RmperformserviceController < WktimeController
  unloadable
	menu_item	:apartment


	def index
		new
	end
	
	def new
		set_user_projects
		@selected_project = getSelectedProject(@manage_projects, true)
		# get the startday for current week
		@startday = Date.today
	end

	def getSheetView
		"I"
	end
	
	def hideprevTemplate
		true
	end
	
	def getCondition(date_field, user_id, start_date, end_date=nil)
		trackerId = Setting.plugin_erpmine_resident['rm_service_tracker']
		@renderer.issue_join_cond = " and i.tracker_id = #{trackerId}"
		@renderer.spent_for_join = " left join rm_resident_services rs on (i.id = rs.issue_id and ap.parent_type = rs.resident_type and ap.parent_id = rs.resident_id )"
		@renderer.spent_for_cond = " and rs.id IS NOT NULL and (rs.end_date is null or rs.end_date >= '#{start_date}')"
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
		# if api_request? && params[:user_id].blank?
			# teName = getTEName()
			# u_id = params[:"wk_#{teName}"][:user][:id]
		# else
			# u_id = params[:user_id]
		# end
		# if !u_id.blank?	&& u_id.to_i != 0
			# @user ||= User.find(u_id)
			# if User.current == @user
				# @logtime_projects ||= Project.where(Project.allowed_to_condition(@user, :log_time)).order('name')
			# else
				# hookProjs = call_hook(:controller_get_permissible_projs, {:user => @user})
				# if !hookProjs.blank?	
					# @logtime_projects = hookProjs[0].blank? ? [] : hookProjs[0]
				# else
					# user_projects ||= Project
					# .joins("INNER JOIN #{EnabledModule.table_name} ON projects.id = enabled_modules.project_id and enabled_modules.name='time_tracking'")
					# .joins("INNER JOIN #{Member.table_name} ON projects.id = members.project_id")				
					# .where("#{Member.table_name}.user_id = #{@user.id} AND #{Project.table_name}.status = #{Project::STATUS_ACTIVE}")
					# logtime_projects ||= Project.where(Project.allowed_to_condition(@user, :log_time)).order('name')
					# @logtime_projects = logtime_projects | user_projects
				# end
			# end
			Rails.logger.info("======== perform service controller ================")
			@logtime_projects = Project.where(:id => getDefultProject) 
			@logtime_projects = setTEProjects(@logtime_projects)
		# end
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
			if isAccountUser
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
end
