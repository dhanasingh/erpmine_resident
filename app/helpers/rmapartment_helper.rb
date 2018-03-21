module RmapartmentHelper
include WkproductitemHelper
include WktimeHelper
include WkaccountprojectHelper
include WktimeHelper
include WkcrmenumerationHelper

	def resident_tabs
		if params[:controller] == "rmapartment" || params[:controller] == "rmresident" || params[:controller] == "rmperformservice"
			tabs = [
				{:name => 'rmapartment', :partial => 'wktime/tab_content', :label => :label_apartment},
				{:name => 'rmresident', :partial => 'wktime/tab_content', :label => :label_resident},
				{:name => 'rmperformservice', :partial => 'wktime/tab_content', :label => :label_perform_service}
			   ]
		end
		tabs
	end
	
	def bedsArray(apartmentId, needBlank, loadDD)
		bedArr = Array.new
		inventoryObj = WkInventoryItem.where(:parent_id => apartmentId).includes(:asset_property)#.where(:wk_asset_properties => {:matterial_entry_id => nil} )
		if loadDD
			inventoryObj = inventoryObj.where(:wk_asset_properties => {:matterial_entry_id => nil} )
		end
		inventoryObj.each do |entry|
			bedArr << [(entry.asset_property.blank? ? "" : entry.asset_property.name.to_s), entry.id]
		end
		bedArr.unshift(["",""]) if needBlank
		bedArr
	end
	
	def residentMoveIn(contactId, contactType, moveInDate, moveOutDate, invItemId, apartmentId, bedId, rate, moveInHr, moveInMm)
		# save Resident
		rmResidentObj = saveResident(nil, contactId, contactType, moveInDate,nil, apartmentId, bedId)
		#save Billable Projects for resident
		projectId = getResidentPluginSetting('rm_project')
		rentalTrackerId = getResidentPluginSetting('rm_rental_tracker')
		issueObj = Issue.where(:tracker_id => rentalTrackerId)
		issueId = issueObj.blank? ? 0 : issueObj[0].id
		activityObj = Enumeration.where(:type => 'TimeEntryActivity')
		activityId = activityObj.blank? ? 0 : activityObj[0].id
		uomObj = WkMesureUnit.all
		uomId = uomObj.blank? ? 0 : uomObj[0].id
		saveBillableProjects(nil, projectId, contactId, contactType, false, true, 'TM')
		#log asset entries for resident
		materialObj = saveMatterialEntries(nil, projectId, User.current.id, issueId, 1, rate, '$', activityId, moveInDate, invItemId, uomId)
		# update material id for used asset
		invItemObj = WkInventoryItem.find(invItemId)
		assetProperty = invItemObj.asset_property
		assetProperty.matterial_entry_id = materialObj.id
		assetProperty.save
		
		# save spent for resident
		saveSpentFor(nil, contactId, contactType, materialObj.id, materialObj.class.name, moveInDate, moveInHr, moveInMm, nil)
	
	end
	
	def saveResident(id, residentId, residentType, moveInDate, moveOutDate, invItemId, bedId)
		rmResidentObj = nil
		if id.blank?
			rmResidentObj = RmResident.new
		else
			rmResidentObj = RmResident.find(id.to_i)
		end
		rmResidentObj.resident_id = residentId
		rmResidentObj.resident_type = residentType
		rmResidentObj.move_in_date = moveInDate
		rmResidentObj.move_out_date = moveOutDate
		rmResidentObj.apartment_id = invItemId
		rmResidentObj.bed_id = bedId
		if rmResidentObj.new_record?
			rmResidentObj.created_by_user_id = User.current.id
		end
		rmResidentObj.updated_by_user_id = User.current.id
		rmResidentObj.save
		rmResidentObj
	end
	
	def saveMatterialEntries(id, projectId, userId, issueId, quantity, sellingPrice, currency, activityId, spentOn, invItemId, uomId)
		if id.blank?
			matterialObj = WkMaterialEntry.new
		else
			matterialObj = WkMaterialEntry.find(id.to_i)
		end
		matterialObj.project_id = projectId
		matterialObj.user_id = userId
		matterialObj.issue_id = issueId
		matterialObj.quantity = quantity
		matterialObj.selling_price = sellingPrice
		matterialObj.currency = currency
		matterialObj.activity_id = activityId
		matterialObj.spent_on = spentOn
		matterialObj.inventory_item_id = invItemId
		matterialObj.uom_id = uomId
		matterialObj.save
		matterialObj
	end
	
	def residentMoveOut(id, spentDate, spentHr,  spentMm)
		unless id.blank?
			resObj = RmResident.find(id.to_i)
		end
		dateVal = getDateTime(spentDate, spentHr, spentMm, '00')
		resObj.move_out_date = spentDate #dateVal
		resObj.save
		unblockApartBeds(resObj)
	end
	
	def unblockApartBeds(resObj)
		assetObj = resObj.apartment.asset_property
		assetObj.matterial_entry_id = nil
		assetObj.save
	end
	
	def settings_tabs		   
		tabs = [				
				{:name => 'resident', :partial => 'settings/tab_resident', :label => :label_general}
			   ]	
	end	
	
	def getResidentPluginSetting(setting_name)
		Setting.plugin_erpmine_resident[setting_name]
	end

end
