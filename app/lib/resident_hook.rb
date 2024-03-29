class ResidentHook < Redmine::Hook::ViewListener
	def external_erpmine_menus(context={})
		menuArr = Array.new(3)
		# define resident menu controller name
		menuArr = ["rmapartment", "rmresident", "rmperformservice"]
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
		context[:survey_types][l(:label_resident)] = "RmResident"
	end

	def find_survey_for(context={})
      result = RmResident.left_join_contacts
      surveyForIDSql = " (rm_residents.id = #{context[:surveyForID]})"
      surveyForSql = " (rm_residents.id = #{context[:surveyForID]} OR LOWER(first_name) LIKE LOWER('#{context[:surveyFor]}') OR LOWER(last_name) LIKE LOWER('#{context[:surveyFor]}') OR LOWER(name) LIKE LOWER('#{context[:surveyFor]}'))" unless context[:surveyFor].blank?
	  result = result.where(context[:method] == "search" ? surveyForSql : surveyForIDSql)
	  .select("rm_residents.id, wk_accounts.name as account_name, first_name, last_name, resident_type")

      result.each do  |r|
				residentName = r.resident_type == "WkAccount" ? r.account_name : r.first_name + " " + r.last_name
		context[:data] << {id: r.id, label: "Resident #" + r.id.to_s + ": " + residentName, value: r.id}
      end
	end

	def getSurveyForType(context={})
		residentID = context[:params][:rm_resident_id]
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

	def get_resident_settings(context={})
		settings = context[:configs][:settings] || {}
		userlanguage = User.current.language
		if userlanguage != 'en'
			languageSet = context[:configs][:languageSet] || {}
			path = "plugins/erpmine_resident/config/locales/en.yml"
			File.open(path).each do |line|
				key, value = line.chomp.split(":")
				languageSet[key.strip] = value.strip if value.present?
			end
		end
		settings[:resident_module] = true
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
end