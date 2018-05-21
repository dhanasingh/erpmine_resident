module RmresidentHelper
#include RmapartmentHelper
include WktimeHelper
include WkassetHelper
include WkpayrollHelper
include WkinvoiceHelper
include WkproductitemHelper
include WkaccountprojectHelper
include WklogmaterialHelper	


	WkCrmContact.class_eval do
		has_many :resident_services, as: :resident, :dependent => :restrict_with_error, :class_name => 'RmResidentService'
		has_many :residents, as: :resident, :dependent => :restrict_with_error, :class_name => 'RmResident'
		#has_one :current_resident, as: :resident, :dependent => :restrict_with_error, :class_name => 'RmResident'
		#scope :current_resident, joins(:residents).merge(RmResident.current_resident)
		#scope :status, lambda {|arg| where(arg.blank? ? nil : {:status => arg.to_i}) }
	end

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

	def residentArray(needBlank)
		resdientArr = Array.new
		residentObj = RmResident.current_resident.left_join_contacts.order("wk_crm_contacts.first_name, wk_crm_contacts.last_name") 
		residentObj.each do | resident |
			resdientArr << [resident.resident.name, resident.resident.id]
		end
		resdientArr.unshift(["",""]) if needBlank
		resdientArr
	end	
	
	def moveInOutHash
		moveHash = {
			'' => "",
			'MI' => l(:button_move_in),
			'MO' => l(:label_move_out)		
		}
		moveHash
	end
	
	# Add Rent, Amenities Entries for next invoice cycle
	def addUnbilledEntries(contactId, entryDate, quantity)
		# invPeriod = getInvoiceFrequency #Setting.plugin_redmine_wktime['wktime_generate_invoice_period']
		# invDay = getInvWeekStartDay #Setting.plugin_redmine_wktime['wktime_generate_invoice_day']
		# invMonthDay = getMonthStartDay #should get from settings
		# periodStart = invPeriod == 'W' ? invDay : invMonthDay
		contact = WkCrmContact.find(contactId)
		currentResident = contact.residents.where("rm_residents.move_out_date is null OR rm_residents.move_out_date >= ?", entryDate).first
		nextInvInterval = getInvoiceInterval(entryDate, entryDate, true, true) #getIntervals(entryDate, entryDate, invPeriod, periodStart, true, true)
		# periodArr = getFinancialPeriodArray(entryDate, entryDate, invPeriod, invMonthDay)
		unless currentResident.blank?
			addNewRentalEntry(currentResident, nextInvInterval[0], quantity)
			services = contact.resident_services.where("rm_resident_services.start_date <= ? AND (rm_resident_services.end_date is null OR rm_resident_services.end_date >= ?)", nextInvInterval[0][1], nextInvInterval[0][0])
			services.each do |service|
				addNewAmenityEntry(service, nextInvInterval[0], quantity)
			end
		end
	end
	
	# Add Rent, Amenities Entries for next invoice cycle
	def addNewAmenityEntry(service, invInterval, quantity)
		issue = Issue.find(service.issue_id)
		if issue.tracker_id == getResidentPluginSetting('rm_amenity_tracker').to_i
			rateHash = getIssueRateHash(issue)
			invInterval[0] = service.start_date if  service.start_date > invInterval[0]
			invInterval[1] = service.end_date if !service.end_date.blank? && service.end_date < invInterval[1]
			# invDay = getInvWeekStartDay #Setting.plugin_redmine_wktime['wktime_generate_invoice_day']
			# invMonthDay = getMonthStartDay #should get from settings
			# periodStart = rateHash['rate_per'] == 'W' ? invDay.to_i : invMonthDay
			periodStart = getPeriodStart(rateHash['rate_per'])
			serviceInterval = getIntervals(invInterval[0], invInterval[1], rateHash['rate_per'], periodStart, true, true)
			serviceInterval.each_with_index do |interval, index|
				intervalStart = interval[0] < invInterval[0] ? invInterval[0] : interval[0]
				intervalEnd = interval[1] > invInterval[1] ? invInterval[1] : interval[1]
				# Add entries in the beginning of the interval so here we take intervalStart
				teCount = TimeEntry.joins(:spent_for).where(:spent_on => intervalStart, :issue_id => service.issue_id, wk_spent_fors: { spent_for_type: service.resident_type, spent_for_id: service.resident_id }).count
				teEntry = nil
				unless teCount > 0
					quantity = getDuration(intervalStart, intervalEnd, rateHash['rate_per'], 0, false)
					teAttributes = { project_id: issue.project_id, issue_id: service.issue_id, hours: quantity, comments: l(:label_auto_populated_entry), activity_id: getDefultActivity, spent_on: intervalStart, spent_for_attributes: { spent_for_id: service.resident_id, spent_for_type: service.resident_type, spent_on_time: intervalStart.to_datetime } }
					teEntry = TimeEntry.new(teAttributes)
					teEntry.user_id = User.current.id
					teEntry.save
				end
				teEntry
			end
		end
	end
	
	def delAutoGenAmenityEntries(residentAmenity)
		amenityEntries =  TimeEntry.joins(:spent_for).where(:issue_id => residentAmenity.issue_id, wk_spent_fors: { spent_for_id: residentAmenity.resident_id, spent_for_type: residentAmenity.resident_type, invoice_item_id: nil}).where("time_entries.spent_on < ? OR time_entries.spent_on > ? ", residentAmenity.start_date, residentAmenity.end_date)
		amenityEntries.destroy_all
		
	end
	
	def addNewRentalEntry(currentResident, invInterval, quantity)
		residingOn = currentResident.bed.blank? ? currentResident.apartment : currentResident.bed
		assetProperty = residingOn.asset_property
		currentMEntry = assetProperty.material_entry
		sellPrice = currentMEntry.blank? ? assetProperty.rate: currentMEntry.selling_price
		rentCurrency = currentMEntry.blank? ? assetProperty.currency : currentMEntry.currency
		uomId = currentMEntry.blank? ? residingOn.uom_id : currentMEntry.uom_id
		# invDay = getInvWeekStartDay #Setting.plugin_redmine_wktime['wktime_generate_invoice_day']
		# invMonthDay = getMonthStartDay #should get from settings
		# periodStart = assetProperty.rate_per == 'W' ? invDay : invMonthDay
		periodStart = getPeriodStart(assetProperty.rate_per)
		invInterval[0] = currentResident.move_in_date.to_date if  currentResident.move_in_date.to_date > invInterval[0]
		invInterval[1] = currentResident.move_out_date.to_date if !currentResident.move_out_date.blank? && currentResident.move_out_date.to_date < invInterval[1]
		rentInterval = getIntervals(invInterval[0], invInterval[1], assetProperty.rate_per, periodStart, true, true)
		rentalIssue = getRentalIssue
		meEntry = nil
		rentInterval.each_with_index do |interval, index|
			intervalStart = interval[0] < invInterval[0] ? invInterval[0] : interval[0]
			intervalEnd = interval[1] > invInterval[1] ? invInterval[1] : interval[1]
			# Add entries in the beginning of the interval so here we take intervalStart
			meCount = WkMaterialEntry.joins(:spent_for).where(:spent_on => intervalStart, :issue_id => rentalIssue.id, wk_spent_fors: { spent_for_type: currentResident.resident_type, spent_for_id: currentResident.resident_id }).count
			unless meCount > 0
				meEntry = nil
				quantity = getDuration(intervalStart, intervalEnd, assetProperty.rate_per, 0, false)
				meAttributes = { project_id: rentalIssue.project_id, issue_id: rentalIssue.id, comments: l(:label_auto_populated_entry), activity_id: getDefultActivity, spent_on: intervalStart, quantity: quantity, quantity_returned: nil, org_selling_price: nil, is_deleted: false, org_currency: nil, selling_price: sellPrice, currency: rentCurrency, uom_id: uomId, inventory_item_id: residingOn.id, spent_for_attributes: { spent_for_id: currentResident.resident_id, spent_for_type: currentResident.resident_type, spent_on_time: intervalStart.to_datetime } }
				meEntry = WkMaterialEntry.new(meAttributes)
				meEntry.user_id = User.current.id
				meEntry.save
			end
			meEntry
		end
		unless meEntry.blank?
			assetProperty.matterial_entry_id = meEntry.id
			assetProperty.save
		end
	end
	
	def getDefultActivity
		activityObj = Enumeration.where(:type => 'TimeEntryActivity')
		activityId = activityObj.blank? ? 0 : activityObj[0].id
		activityId #get from settings
	end
	
	def getResidentServicePeriod(invStartDt, invEndDt, residentId, residentType, issue)
		projectId = getResidentPluginSetting('rm_project').to_i
		periodHash = {"start" => invStartDt, "end" => invEndDt}
		if issue.project_id == projectId
			residentService = RmResidentService.where(:resident_id => residentId, :resident_type => residentType, :issue_id => issue.id).where("(end_date is null OR end_date >= ?) AND start_date <= ? ", invStartDt, invEndDt).first
			unless residentService.blank?
				startDt = residentService.start_date > invStartDt ? residentService.start_date : invStartDt
				endDt = residentService.end_date.blank? || residentService.end_date > invEndDt ? invEndDt : residentService.end_date
				periodHash = {"start" => startDt, "end" => endDt}
			end
		end
		periodHash
	end
	
	def residentMoveIn(contactId, contactType, moveInDate, moveOutDate, invItemId, apartmentId, bedId, rate, moveInHr, moveInMm)
		errorMsg = ""
		projectId = getResidentPluginSetting('rm_project')
		rentalIssue = getRentalIssue
		unless projectId.blank? || rentalIssue.blank?
			# save Resident
			rmResidentObj = saveResident(nil, contactId, contactType, moveInDate,nil, apartmentId, bedId)
			#save Billable Projects for resident
			
			# rentalTrackerId = getResidentPluginSetting('rm_rental_tracker')
			# issueObj = Issue.where(:tracker_id => rentalTrackerId)
			# issueId = issueObj.blank? ? 0 : issueObj[0].id
			
			activityObj = Enumeration.where(:type => 'TimeEntryActivity')
			activityId = activityObj.blank? ? 0 : activityObj[0].id
			uomObj = WkMesureUnit.all
			uomId = uomObj.blank? ? 0 : uomObj[0].id
			saveBillableProjects(nil, projectId, contactId, contactType, false, true, 'TM')
			#log asset entries for resident
			
			materialObj = saveMatterialEntries(nil, projectId, User.current.id, rentalIssue.id, 1, rate, '$', activityId, moveInDate, invItemId, uomId)
			# update material id for used asset
			invItemObj = WkInventoryItem.find(invItemId)
			assetProperty = invItemObj.asset_property
			assetProperty.matterial_entry_id = materialObj.id
			assetProperty.save
			
			# save spent for resident
			saveSpentFor(nil, contactId, contactType, materialObj.id, materialObj.class.name, moveInDate, moveInHr, moveInMm, nil)
			
			#update the rental proration
			rentalProration(rmResidentObj)
		else
			errorMsg = l(:label_movein_error_msg)
		end
		errorMsg
	end
	
	# Return the issue for rental material entries
	def getRentalIssue
		projectId = getResidentPluginSetting('rm_project')
		rentalTrackerId = getResidentPluginSetting('rm_rental_tracker')
		trackerIssues = Issue.where(:tracker_id => rentalTrackerId)
		issue = trackerIssues.blank? ? nil : trackerIssues[0]
		issue
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
			moveInDate = nil
			moveOutDate = nil
			moveInDate = resObj.move_in_date.to_date unless resObj.move_in_date.blank?
			moveOutDate = resObj.move_out_date.to_date unless resObj.move_out_date.blank?
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
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm', 1)[0][1] : moveOutDate
			#ratioVal = hoursRatio(moveInDate, endDate)
			ratioVal = getDuration(moveInDate, endDate, 'h', 1, false)
		when 'm'
			monthStartDay = getMonthStartDay
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm', monthStartDay)[0][1] : moveOutDate
			#ratioVal = monthsBetween(moveInDate, endDate)
			ratioVal = getDuration(moveInDate, endDate, 'm', 1, false)
		when 'd'
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm', 1)[0][1] : moveOutDate
			ratioVal = getDuration(moveInDate, endDate, 'd', 1, false)
			#ratioVal = hoursRatio(moveInDate, endDate)		
		when 'q'
			monthStartDay = getMonthStartDay
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm', monthStartDay)[0][1] : moveOutDate
			#ratioVal = quarterRatio(moveInDate, endDate)
			ratioVal = getDuration(moveInDate, endDate, 'q', 1, false)
		when 'sa'
			monthStartDay = getMonthStartDay
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm', monthStartDay)[0][1] : moveOutDate
			ratioVal = getDuration(moveInDate, endDate, 'sa', 1, false)
		when 'a'
			monthStartDay = getMonthStartDay
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm', monthStartDay)[0][1] : moveOutDate
			#ratioVal = getYearlyDiff(moveInDate, endDate)
			ratioVal = getDuration(moveInDate, endDate, 'a', 1, false)
		when 'w'
			weekStartDay = getInvWeekStartDay
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm', weekStartDay)[0][1] : moveOutDate
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
	
	def getRentalRate(id)
		rate = 0 
		unless id.blank?
			invItemObj = WkInventoryItem.find(id.to_i)
			rate = invItemObj.asset_property.blank? ? 0 : invItemObj.asset_property.rate unless invItemObj.blank?
		end
		rate
	end
end
