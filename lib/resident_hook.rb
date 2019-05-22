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
		sectionArr = ["rmresident", "rmamentity"] if context[:curObj].contact_type == "RA"
		sectionArr
	end

	def remove_exsisting_accordion_section(context={})
		removed_sections = Array.new
		removed_sections = ["wkaccountproject"] if context[:curObj].contact_type == "RA"
		removed_sections
	end
	
	def controller_convert_contact(context={})
		type = Array.new		
		type << 'C'
		type << 'wkcrmcontact'
		unless context[:params].blank?
			unless context[:params][:apartment_idM].blank?
				type.clear
				type << 'RA'
				type << 'rmresident'
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
		nextBillStart = invEndDt.to_date + 1.day
		resident_helper.addUnbilledEntries(parentId.to_i, nextBillStart, 1)
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
	
	def additional_contact_type(context={})
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
	render_on :additional_contact_info, :partial => 'rmresident/additional_resident_info'
end