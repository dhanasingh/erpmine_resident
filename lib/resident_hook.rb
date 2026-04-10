class ResidentHook < Redmine::Hook::ViewListener
	include RmresidentHelper
	def external_erpmine_menus(context={})
		menuArr = []
		menuArr << "rmapartment"      if show_apartment
		menuArr << "rmresident"       if show_resident
		menuArr << "rmperformservice" if show_service
		menuArr << "rmincident"       if show_incident
		menuArr << "rmevaluation"     if show_evaluation

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
		sectionArr = ["rmresident", "rmamentity"] if getResidentType(context) == "RA"
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

	def add_survey_for(context={})
		context[:survey_types] = {l(:label_resident) => "RmResident"}
	end

	def find_survey_for(context={})
      result = RmResident.left_join_contacts
      surveyForIDSql = " (rm_residents.id = #{context[:surveyForID]})"
      surveyForSql = " (rm_residents.id = #{context[:surveyForID]} OR LOWER(first_name) LIKE LOWER('#{context[:surveyFor]}') OR LOWER(last_name) LIKE LOWER('#{context[:surveyFor]}') OR LOWER(name) LIKE LOWER('#{context[:surveyFor]}'))" unless context[:surveyFor].blank?
	  result = result.where(context[:method] == "search" ? surveyForSql : surveyForIDSql)
	  .select("rm_residents.id, wk_accounts.name as account_name, first_name, last_name, resident_type")

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

	def get_permission_modules(context={})
		context[:modules].merge!(
			"Resident"   => l(:label_resident),
			"Apartment"  => l(:label_apartment),
			"Incident"   => l(:label_incident),
			"Evaluation" => l(:label_evaluation)
		)
	end

	# def load_resident_permissions(context={})
	# 	context[:perms].concat([
	# 		{ name: 'VIEW RESIDENT',       short_name: 'V_RES',       modules: 'Resident'   },
	# 		{ name: 'ADMIN RESIDENT',      short_name: 'A_RES',       modules: 'Resident'   },
	# 		{ name: 'BASIC BED PRIVILEGE', short_name: 'B_BED_PRVLG', modules: 'Apartment'  },
	# 		{ name: 'ADMIN BED PRIVILEGE', short_name: 'A_BED_PRVLG', modules: 'Apartment'  },
	# 		{ name: 'BASIC INCIDENT',      short_name: 'B_INC',       modules: 'Incident'   },
	# 		{ name: 'ADMIN INCIDENT',      short_name: 'A_INC',       modules: 'Incident'   },
	# 		{ name: 'VIEW EVALUATION',     short_name: 'V_EVL',       modules: 'Evaluation' },
	# 		{ name: 'MANAGE EVALUATION',   short_name: 'M_EVL',       modules: 'Evaluation' },
	# 		{ name: 'ADMIN SERVICE',        short_name: 'A_SVC',       modules: 'Service'   }
	# 	])
	# end

	#render_on :render_permission_fieldset, :partial => 'rmpermission/resident_permissions'

	render_on :resident_evaluation, :partial => 'rmevaluation/evaluation'
end
