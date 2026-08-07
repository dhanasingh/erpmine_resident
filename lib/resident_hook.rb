class ResidentHook < Redmine::Hook::ViewListener
	include RmresidentHelper
	def external_erpmine_menus(context={})
		menuArr = []
		menuArr << "rmapartment"      if show_apartment
		menuArr << "rmresident"       if show_resident
		menuArr << "rmperformservice" if show_service
		menuArr << "rmincident"       if show_incident
		menuArr << "rmevaluation"     if show_evaluation
		menuArr << "rmdashboard"      if show_resident

		menuArr
	end

	def view_asset_inventory(context={})
		"<input type='hidden' value='1' name='available_quantity' id='available_quantity' > "
	end

	def view_asset_fields(context={})
		false
	end

	def view_product_item(context={})
		"<input type='hidden' value='1' name='available_quantity' id='available_quantity' >"
	end

	def view_accordion_section(context={})
		sectionArr = Array.new(3)
		sectionArr = ["rmresident", "rmamentity", "rmcare"] if getResidentType(context) == "RA"
		sectionArr
	end

	def remove_existing_accordion_section(context={})
		removed_sections = Array.new
		removed_sections = ["wkaccountproject"] if getResidentType(context) == "RA"
		removed_sections
	end

	def controller_convert_contact(context={})
		type = Array.new
		type << 'C'
		type << 'wkcrmcontact'
		if !context[:accountObj].blank?
			type.clear
			type << 'A'
			type << 'wkcrmaccount'
		end
		unless context[:params].blank?
			unless context[:params][:apartment_idM].blank?
				id = !context[:accountObj].blank? ? getResident(context[:accountObj].id, 'WkAccount') : getResident(context[:contactObj].id, 'WkCrmContact')
				type.clear
				type << 'RA'
				type << 'rmresident'
				type << id
				type << "rm_resident_id"
			end
		end
		type
	end

	#After the lead conversion update the resident, billable projects, asset properties and log asset (material entry, spent for)
	def controller_updated_contact(context={})
		errorMsg = ""
		if context[:contactObj].contact_type == "RA"
			rmresident_helper = Object.new.extend(RmresidentHelper)
			contactId = context[:contactObj].id
			contactType = 'WkCrmContact'
			moveInDate = context[:params][:move_in_date]
			moveInHr = context[:params][:move_in_hr]
			moveInMm = context[:params][:move_in_min]
			invItemId = context[:params][:bed_idM].blank? ? context[:params][:apartment_idM] : context[:params][:bed_idM]

			errorMsg = rmresident_helper.residentMoveIn(contactId, contactType, moveInDate, nil, invItemId, context[:params][:apartment_idM], context[:params][:bed_idM], context[:params][:rateM], moveInHr, moveInMm)
		end
		errorMsg
	end

	def controller_after_save_invoice(context={})
		resident_helper = Object.new.extend(RmresidentHelper)
		invEndDt = context[:attributes]["end_date"]
		parentId = context[:attributes]["parent_id"]
		parentType = context[:attributes]["parent_type"]
		nextBillStart = invEndDt.to_date + 1.day
		resident_helper.addUnbilledEntries(parentId.to_i, nextBillStart, 1, parentType)
	end

	def get_entry_billing_quantity(context={})
		entry   = context[:entry]
		invoice = context[:invoice]
		return if entry.blank? || invoice.blank?

		resident_helper = Object.new.extend(RmresidentHelper)
		care_tracker_id = resident_helper.getResidentPluginSetting('rm_care_tracker').to_i
		return unless care_tracker_id > 0 && entry.issue&.tracker_id == care_tracker_id
		return unless entry.spent_on < invoice.start_date.to_date

		rate_hash = context[:rate_hash]
		rate_per  = rate_hash&.fetch('rate_per', nil)
		if rate_per.blank?
			issue_rate_hash = resident_helper.getIssueRateHash(entry.issue)
			rate_per = issue_rate_hash&.fetch('rate_per', nil)
		end
		return if rate_per.blank?

		account_project = context[:account_project]
		return if account_project.blank?

		periods = resident_helper.getResidentServicePeriod(
			invoice.start_date, invoice.end_date,
			account_project.parent_id, account_project.parent_type,
			entry.issue
		)
		return if periods.blank? || periods[0].blank?

		p = periods[0]
		totalHours = resident_helper.getDaysBetween(p["start"], p["end"]) * 24
		resident_helper.getDuration(p["start"], p["end"], rate_per, totalHours, false)
	end

	# Care entries are billed strictly by the issue's care-level rate
	# (looked up via points), never by the project's billing rate.
	def get_entry_billing_rate(context={})
		entry = context[:entry]
		return if entry.blank? || entry.issue.blank?

		resident_helper = Object.new.extend(RmresidentHelper)
		care_tracker_id = resident_helper.getResidentPluginSetting('rm_care_tracker').to_i
		return unless care_tracker_id > 0 && entry.issue.tracker_id == care_tracker_id

		issue_rate_hash = resident_helper.getIssueRateHash(entry.issue)
		return if issue_rate_hash.blank? || issue_rate_hash['rate'].blank? || issue_rate_hash['rate'] <= 0

		issue_rate_hash
	end

	def append_recurring_unbilled_entries(context={})
		invoice         = context[:invoice]
		account_project = context[:account_project]
		return if invoice.blank? || account_project.blank?

		resident_helper = Object.new.extend(RmresidentHelper)
		care_tracker_id = resident_helper.getResidentPluginSetting('rm_care_tracker').to_i
		return if care_tracker_id.blank? || care_tracker_id == 0

		inv_start   = invoice.start_date.to_date
		parent_id   = account_project.parent_id
		parent_type = account_project.parent_type

		time_entries = context[:time_entries]
		existing_ids = time_entries.pluck(:id)

		# Skip if a care entry already exists within the invoice period
		care_in_period = TimeEntry.joins(:issue)
			.where(id: existing_ids, issues: { tracker_id: care_tracker_id })
			.exists?
		return if care_in_period

		# Find the latest care time entry for this resident
		latest = TimeEntry.joins(:spent_for)
			.joins(:issue)
			.where(
				issues:        { tracker_id: care_tracker_id },
				wk_spent_fors: { spent_for_type: parent_type, spent_for_id: parent_id }
			)
			.where("time_entries.spent_on < ?", inv_start)
			.order("time_entries.spent_on DESC")
			.first

		return if latest.blank?

		context[:time_entries] = TimeEntry.includes(:spent_for)
			.where(id: existing_ids + [latest.id])
	end

	def additional_product_type(context={})
		productTypeHash
	end

	def external_enum_type(context={})
		enumHash = Hash.new()
		enumHash["MOR"] = l(:label_move_out_reason)
		enumHash[RmIncident::INCIDENT_ENUM_TYPE] = l(:field_incident_type)
		enumHash
	end

	def get_invoice_issue_period(context={})
		resident_helper = Object.new.extend(RmresidentHelper)
		invStartDt = context[:attributes]["start_date"]
		invEndDt = context[:attributes]["end_date"]
		parentId = context[:attributes]["parent_id"]
		parentType = context[:attributes]["parent_type"]
		period = resident_helper.getResidentServicePeriod(invStartDt, invEndDt, parentId, parentType, context[:issue])
		period
	end

	def additional_type(context={})
		"RA"
	end

	def payment_additional_where_query(context={})
		" OR CASE WHEN p.parent_type = 'WkAccount'  THEN a.account_type ELSE c.contact_type END = 'RA'"
	end

	def additional_spent_type(context={})
		productTypeHash
	end

	def productTypeHash
		productHash = Hash.new()
		productHash["RA"] = l(:label_resident) + " " + l(:label_asset)
		productHash
	end

	def retrieve_time_entry_query_model(context={})
		model = nil
		if !context[:params][:spent_type].blank? && context[:params][:spent_type] == "RA"
			model = WkMaterialEntryQuery
		end
		model
	end

	def time_entry_detail_where_query(context={})
		time_entry_where_query(context[:params][:spent_type])
	end

	def time_entry_report_where_query(context={})
		time_entry_where_query(context[:params][:spent_type])
	end

	def time_entry_where_query(spentType)
		strQuery = ""
		if !spentType.blank? && spentType == "RA"
			strQuery = "wk_inventory_items.product_type = 'RA' "
		end
		strQuery
	end

	def create_time_entry_log_type(context={})
		"RA"
	end

	def update_time_entry_log_type(context={})
		"RA"
	end

	def modify_product_log_type(context={})
		"RA"
	end

	render_on :view_additional_lead_info, :partial => 'rmresident/move_in'

	def find_survey_for(context={})
      result = RmResident.left_join_contacts
      surveyForIDSql = " (rm_residents.id = #{context[:surveyForID]})"
      surveyForSql = " (rm_residents.id = #{context[:surveyForID]} OR LOWER(first_name) LIKE LOWER('#{context[:surveyFor]}') OR LOWER(last_name) LIKE LOWER('#{context[:surveyFor]}') OR LOWER(name) LIKE LOWER('#{context[:surveyFor]}'))" unless context[:surveyFor].blank?
	  result = result.where(context[:method] == "search" ? surveyForSql : surveyForIDSql)
	  .select("rm_residents.id, wk_accounts.name as account_name, first_name, last_name, resident_type")
	  # Restrict the resident dropdown to the user's permitted location subtree,
	  # matching the evaluation list (surveyList). nil ids => unrestricted => no-op.
	  result = WkLocation.filter_by_contact_account_location(result, WkLocation.accessible_location_ids)

      result.each do  |r|
				residentName = r.resident_type == "WkAccount" ? r.account_name : (r&.first_name || '' + " " + r&.last_name || '')
		context[:data] << {id: r.id, label: "Resident #" + r.id.to_s + ": " + residentName, value: r.id}
      end
	end

	def getSurveyForType(context={})
		residentID = context[:params][:rm_resident_id] if !context[:params][:rm_resident_id].blank?
		unless residentID.blank?
			resObj = RmResident.find(residentID)
			rm_resident = RmResident.where(" id = ? and resident_type = ?", residentID, resObj.resident_type).first
		end
		if !rm_resident.blank? || context[:params][:surveyForType] == "RmResident"
			context[:surveyFor][:surveyForType] = "RmResident"
			context[:surveyFor][:surveyForID] = context[:params][:surveyForID].blank? ? (!context[:params][:lead_id].blank? ? rm_resident.id : context[:params][:rm_resident_id]) : context[:params][:surveyForID]
		end
	end

	def get_survey_url(context={})
		if context[:urlHash][:surveyForType] == "RmResident" && context[:urlHash][:surveyForID].blank?
			residentID = context[:params][:rm_resident_id]
			context[:urlHash][:surveyForID] = context[:params][:lead_id].present? ? getResident(context[:params][:contact_id], 'WkCrmContact') : residentID
		end
	end

	def get_survey_redirect_url(context={})
		if context[:urlHash][:surveyForType] == "RmResident" && !context[:urlHash][:surveyForID].blank?
      		context[:urlHash][:controller] = "rmresident"
			context[:urlHash][:action] = 'edit'
			context[:urlHash][:rm_resident_id] = context[:urlHash][:surveyForID]

			# When a resident evaluation is submitted, apply care-rate billing
			if context[:params][:commit] == "Submit"
				begin
					survey_id = context[:params][:survey_id]
					survey    = WkSurvey.find_by(id: survey_id.to_i)
					if survey.try(:affect_billing?) && survey.try(:use_points?)
						rmresident_helper = Object.new.extend(RmresidentHelper)
						rmResident = RmResident.find_by(id: context[:urlHash][:surveyForID].to_i)
						unless rmResident.blank?
							# Prefer the ID of the just-saved response; fall back to the form's existing ID
							resp_id    = context[:params][:saved_survey_response_id] || context[:params][:survey_response_id]
							saved_resp = resp_id.present? ? WkSurveyResponse.find_by(id: resp_id.to_i) : nil
							if saved_resp.blank?
								saved_resp = WkSurveyResponse
									.where(:survey_id       => survey_id,
									       :survey_for_type => 'RmResident',
									       :survey_for_id   => rmResident.id)
									.order(:id => :desc)
									.first
							end
							total_points = saved_resp&.total_points
							unless total_points.blank?
								billing_project_id = rmResident.apartment&.project_id
								care_issue = rmresident_helper.getMatchingCareRate(total_points, billing_project_id)
								if care_issue.present?
									effective_date = context[:params][:effective_date].present? ? context[:params][:effective_date].to_date : Date.today
									rmresident_helper.save_care_billing_assignment(rmResident, saved_resp, effective_date)
									rmresident_helper.upsertCareResidentService(rmResident, care_issue, effective_date)
									care_svc = rmResident.resident_services.reload.where(issue_id: care_issue.id, end_date: nil).first
									if care_svc.present?
										nextInvInterval = rmresident_helper.getInvoiceInterval(effective_date, effective_date, true, true)
										rmresident_helper.addNewAmenityEntry(care_svc, nextInvInterval[0], 1)
									end
								else
									Rails.logger.warn "Care billing: no care issue found for total_points=#{total_points}"
								end
							else
								Rails.logger.warn "Care billing: total_points blank on response id=#{saved_resp&.id}"
							end
						end
					end
				rescue => e
					Rails.logger.error "Care billing upsert failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
					ctrl = context[:controller]
					if ctrl && ctrl.respond_to?(:flash) && ctrl.flash
						# Show the raw validation error (or generic message) to the user so
						msg = e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.join(", ") : e.message
						ctrl.flash[:error] = "#{l(:notice_care_billing_failed)}: #{msg}"
					end
				end
			end
		elsif context[:urlHash][:surveyForType] == "RmResident"
			context[:urlHash][:controller] = "rmevaluation"
			context[:urlHash][:action] = 'index'
			context[:urlHash][:tab] = 'rmevaluation'
		end
	end

	def getDocAccordionSection(context={})
		if context[:controller_name] == "rmresident"
			context[:url][:container_type] = 'RmResident'
			residentID = context[:params][:rm_resident_id]
            context[:url][:container_id] = residentID.blank? ? getResident(context[:params][:contact_id], 'WkCrmContact') : residentID
		end
	end

	def getDocRedirectUrl(context={})
		if context[:container_type] == 'RmResident'
			context[:url][:controller] = 'rmresident'
			context[:url][:action] = 'edit'
			context[:url][:rm_resident_id] = context[:container_id]
		end
	end

	def getResident(id, type)
		resident = RmResident.where(resident_id: id, resident_type: type).first
		resident.id
	end

	def getResidentType(context)
		if context[:entity] == "WkCrmContact"
			type = context[:curObj].contact_type
		else
			type = context[:curObj].account_type
		end
		type
	end

	def get_other_settings(context={})
		settings = context[:configs][:settings] || {}
		context[:configs][:resident_module] = show_resident_menu
		userlanguage = User.current.language
		if userlanguage != 'en'
			languageSet = context[:configs][:languageSet] || {}
			path = "plugins/erpmine_resident/config/locales/en.yml"
			File.open(path).each do |line|
				key, value = line.chomp.split(":")
				languageSet[key.strip] = value.strip if value.present?
			end
		end
		Setting.plugin_erpmine_resident.each{ |key, val| settings[key] = val if val != "" }
	end

	def additional_type_label(context={})
		typeHash = context[:typeHash] || {}
		typeHash['RA'] = l(:label_resident)
	end

	def get_inventory_url(context={})
		if context[:spentType] == 'RA'
			context[:url][:controller] = 'rmapartment'
		end
	end

	def wktime_menu_hook(context = {})
		menu = context[:menu]
		return unless menu.present?
		menu.push :apartment,
						{ controller: 'rmresident', action: 'get_resident_tabs' },
						{ caption: :label_resident,
							if: Proc.new {
								Object.new.extend(RmresidentHelper).show_resident_menu
							}
						}
	end

	def survey_points(context = {})
		points = Array.new
		params = context[:params]
		if params.present? && params[:rm_resident_id].present?
			points.clear
			points << params[:rm_resident_id].to_i
		end
		points
	end

	def get_survey_label(context = {})
		label = {}
		params = context[:params]
		if params.present? && (params[:rm_resident_id].present? || params[:surveyForType] == "RmResident")
			label["header"] = l(:label_evaluation)
			label["newItemLabel"] = l(:label_new_evaluation)
			label["editItemLabel"] = l(:label_edit_evaluation)
			label["response"] = l(:label_evaluation_response)
		end
		label
	end

	def show_survey_link(context={})
		showLink = context[:type][:surveyForType] == "RmResident" && context[:params][:survey_for].blank?  ? true : false
	end
	
	def show_survey_result(context={})
		showResult = context[:type][:surveyForType] == "RmResident"
	end
	

	def add_report_type(context={})
		reports = context[:reports]
		apiRequest = context[:apiRequest]
		reportLoc = Rails.root.join('plugins', 'erpmine_resident', 'app', 'views', 'rmreport')
		Dir["#{reportLoc}/_report*"].each do |path|
			fileName = File.basename(path, '.html.erb')
			fileName.slice!(0)
			# Skip additional-filter partials (e.g. _report_evaluation_filter). They are
			# injected into the report filter form via render_on(:report_additional_filters)
			# and are not selectable report types - listing them produced a bogus
			# "report_evaluation_filter" entry that has no translation and no report module.
			next if fileName.end_with?('_filter')
			label = fileName.remove('_web')
			reports << [l(:"#{label}"), fileName] if Object.new.extend(RmreportHelper).hasViewPermission(label) && (!apiRequest || !(fileName.end_with?('_web')))
		end
		reports.uniq!
	end

	def load_report_module(context={})
		report_type = context[:report_type]
		report_file = Rails.root.join("plugins/erpmine_resident/app/views/rmreport/#{report_type}.rb")
		if File.exist?(report_file)
			require_dependency report_file.to_s
			report = Object.new.extend(report_type.camelize.constantize)
			context[:report_module] << report
		end
	end

	def get_report_view_path(context={})
		report_type = context[:report_type]
		partial_path = Rails.root.join('plugins', 'erpmine_resident', 'app', 'views', 'rmreport', "_#{report_type}.html.erb")
		if File.exist?(partial_path)
			context[:view_path] << 'rmreport/report'
		end
	end

	# Whitelist the evaluation filter so wkreport persists it in the session.
	def add_report_filter_keys(context={})
		context[:filters] << :evaluation_id
	end

	# Supply the extra evaluation_id argument expected by report_evaluation's
	# calcReportData / getExportData, only for that report type.
	def add_report_calc_args(context={})
		if context[:report_type] == 'report_evaluation'
			controller = context[:controller]
			context[:args] << controller.send(:getSession, :evaluation_id)
		end
	end

	# Inject the evaluation filter UI into the wkreport filter form.
	render_on :report_additional_filters, :partial => 'rmreport/report_evaluation_filter'

	def load_other_permissions(context = {})
		context[:perms].concat([
			{ name: 'BASIC RESIDENT PRIVILEGE',  short_name: 'B_RES_PRVLG',  modules: 'Resident',   plugin: 'rm' },
			{ name: 'ADMIN RESIDENT PRIVILEGE',  short_name: 'A_RES_PRVLG',  modules: 'Resident',   plugin: 'rm' },
			{ name: 'BASIC APARTMENT PRIVILEGE', short_name: 'B_APT_PRVLG',  modules: 'Apartment',  plugin: 'rm' },
			{ name: 'ADMIN APARTMENT PRIVILEGE', short_name: 'A_APT_PRVLG',  modules: 'Apartment',  plugin: 'rm' },
			{ name: 'BASIC INCIDENT PRIVILEGE',  short_name: 'B_INC_PRVLG',  modules: 'Incident',   plugin: 'rm' },
			{ name: 'ADMIN INCIDENT PRIVILEGE',  short_name: 'A_INC_PRVLG',  modules: 'Incident',   plugin: 'rm' },
			{ name: 'BASIC EVALUATION PRIVILEGE', short_name: 'B_EVL_PRVLG', modules: 'Evaluation', plugin: 'rm' },
			{ name: 'ADMIN EVALUATION PRIVILEGE', short_name: 'A_EVL_PRVLG', modules: 'Evaluation', plugin: 'rm' },
			{ name: 'VIEW SERVICE', short_name: 'V_SVC', modules: 'Resident', plugin: 'rm' }
		])
	end

	render_on :survey_response_list_header, :partial => 'rmevaluation/survey_response_list_header'
	render_on :survey_response_list_row,    :partial => 'rmevaluation/survey_response_list_row'
	render_on :resident_evaluation, :partial => 'rmevaluation/evaluation'
	render_on :view_wkissue_fields_bottom, :partial => 'rmevaluation/rm_care_issue_fields'
	render_on :view_wkissue_show_bottom,   :partial => 'rmevaluation/rm_care_issue_show'
end
