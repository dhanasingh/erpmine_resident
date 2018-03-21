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
	
	def controller_convert_contact(context={})
		type = Array.new		
		unless context[:params].blank?
			unless context[:params][:apartment_idM].blank?
				type << 'RA'
				type << 'wkcrmcontact'
			end
		else
			type << 'C'
			type << 'wkcrmcontact'
		end
		type
	end
	
	#After the lead conversion update the resident, billable projects, asset properties and log asset (material entry, spent for)
	def controller_updated_contact(context={})
		rmapartment_helper = Object.new.extend(RmapartmentHelper)
		contactId = context[:contactObj].id
		contactType = 'WkCrmContact'
		moveInDate = context[:params][:move_in_date]
		moveInHr = context[:params][:move_in_hr]
		moveInMm = context[:params][:move_in_min]
		invItemId = context[:params][:bed_idM].blank? ? context[:params][:apartment_idM] : context[:params][:bed_idM]
		
		rmapartment_helper.residentMoveIn(contactId, contactType, moveInDate, nil, invItemId, context[:params][:apartment_idM], context[:params][:bed_idM], context[:params][:rate], moveInHr, moveInMm)		
	end
	
	def additional_product_type(context={})
		productHash = Hash.new()
		productHash["RA"] = l(:label_resident)
		productHash
	end
	
	def external_enum_type(context={})
		enumHash = Hash.new()
		enumHash["MOR"] = l(:label_move_out_reason)
		enumHash
	end
	
	render_on :view_additional_lead_info, :partial => 'rmapartment/move_in'	
	render_on :additional_contact_info, :partial => 'rmresident/additional_resident_info'
end