module RmapartmentHelper
include WkproductitemHelper
include WktimeHelper
include WkaccountprojectHelper
include WktimeHelper
include WkcrmenumerationHelper
include WkassetdepreciationHelper
include WkpayrollHelper
include WklogmaterialHelper

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
		
		#update the rental proration
		rentalProration(rmResidentObj)
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
	
	def residentMoveOut(id, spentDate, spentHr,  spentMm, moveOutReason)
		unless id.blank?
			resObj = RmResident.find(id.to_i)
		end
		dateVal = getDateTime(spentDate, spentHr, spentMm, '00')
		resObj.move_out_date = spentDate #dateVal
		resObj.move_out_reason_id = moveOutReason
		resObj.save
		rentalProration(resObj)
		unblockApartBeds(resObj)
	end
	
	def unblockApartBeds(resObj)
		assetObj = nil
		unless resObj.bed.blank?
			assetObj = resObj.bed.asset_property
		else
			assetObj = resObj.apartment.asset_property
		end		
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
	
	def rentalProration(resObj)
		assetObj = nil
		materialObj = nil
		unless resObj.bed.blank?
			assetObj = resObj.bed.asset_property
		else
			assetObj = resObj.apartment.asset_property
		end
		unless assetObj.blank?
			materialObj = assetObj.material_entry 
			moveInDate = resObj.move_in_date
			moveOutDate = resObj.move_out_date
			frequency = assetObj.rate_per
			prorationQuantity = getFrequencyProration(frequency, moveInDate, moveOutDate)
			materialObj.quantity = prorationQuantity
			materialObj.save
		end
	end	
	
	def getFrequencyProration(frequency, moveInDate, moveOutDate)
		ratioVal = 0
		case frequency
		when 'h'
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm')[0][1] : moveOutDate
			#ratioVal = hoursRatio(moveInDate, endDate)
			ratioVal = getDuration(moveInDate, endDate, 'h', 1, false)
		when 'm'
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm')[0][1] : moveOutDate
			#ratioVal = monthsBetween(moveInDate, endDate)
			ratioVal = getDuration(moveInDate, endDate, 'm', 1, false)
		when 'd'
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm')[0][1] : moveOutDate
			ratioVal = getDuration(moveInDate, endDate, 'd', 1, false)
			#ratioVal = hoursRatio(moveInDate, endDate)		
		when 'q'
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm')[0][1] : moveOutDate
			#ratioVal = quarterRatio(moveInDate, endDate)
			ratioVal = getDuration(moveInDate, endDate, 'q', 1, false)
		when 'sa'
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm')[0][1] : moveOutDate
			ratioVal = getDuration(moveInDate, endDate, 'sa', 1, false)
		when 'a'
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm')[0][1] : moveOutDate
			#ratioVal = getYearlyDiff(moveInDate, endDate)
			ratioVal = getDuration(moveInDate, endDate, 'a', 1, false)
		when 'w'
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm')[0][1] : moveOutDate
			ratioVal = getDuration(moveInDate, endDate, 'w', 1, false)
		else
			raise "Given frequency is mismatched"
		end
		ratioVal
	end
	
	def hoursRatio(from, to)
		dayVarients = getDaysBetween(from, to).to_i 
		noOfDays =  dayVarients == 0 ? 1 : dayVarients
		noOfDays
	end
	
	def quarterRatio(startDate, endDate)
		if startDate.beginning_of_quarter == endDate.beginning_of_quarter
			noOfDays = (getDaysBetween(startDate, endDate) ) /  (getDaysBetween(startDate.beginning_of_quarter, startDate.end_of_quarter) * 1.0 )
		else			
			noOfDays = (((getDaysBetween(startDate, startDate.end_of_quarter)) / ((getDaysBetween(startDate.beginning_of_quarter, startDate.end_of_quarter)) * 1.0 )) + ((getDaysBetween(endDate.beginning_of_quarter, endDate))/ ((getDaysBetween(endDate.beginning_of_quarter, endDate.end_of_quarter)) * 1.0)) + (getQuarterDiff((startDate.end_of_quarter + 1) , (endDate.beginning_of_quarter-1))) )
		end
		noOfDays		
	end	
	
	def getQuarterDiff(from, to)
		monthVal = getMonthDiff(from, to)+1
		monthVal/3
	end	
	
	def getYearlyDiff(from, to)
		((to - from) / 365.0).floor
	end

end
