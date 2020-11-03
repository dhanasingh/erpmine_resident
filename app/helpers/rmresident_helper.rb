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
		has_many :residents, as: :resident, class_name: 'RmResident', dependent: :restrict_with_error
		has_many :resident_services, through: :residents
	end

	WkAccount.class_eval do
		has_many :residents, as: :resident, class_name: 'RmResident', dependent: :restrict_with_error
		has_many :resident_services, through: :residents
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

	def residentArray(needBlank, type)
		resdientArr = Array.new
		residentObj = RmResident.current_resident.left_join_contacts.where("resident_type=?", type).order("wk_crm_contacts.first_name, wk_crm_contacts.last_name")
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
	
	def getCurrentResident(id, entryDate, type)
		model = type == "WkAccount" ? WkAccount : WkCrmContact
		@resident = model.find(id)
		currentResident = @resident.residents.where("rm_residents.move_out_date is null OR rm_residents.move_out_date >= ?", entryDate).first
		currentResident
	end

		# Add Rent, Amenities Entries for next invoice cycle
	def addUnbilledEntries(parentId, entryDate, quantity, parentType)
		# invPeriod = getInvoiceFrequency #Setting.plugin_redmine_wktime['wktime_generate_invoice_period']
		# invDay = getInvWeekStartDay #Setting.plugin_redmine_wktime['wktime_generate_invoice_day']
		# invMonthDay = getMonthStartDay #should get from settings
		# periodStart = invPeriod == 'W' ? invDay : invMonthDay
		currentResident = getCurrentResident(parentId, entryDate, parentType)
		nextInvInterval = getInvoiceInterval(entryDate, entryDate, true, true) #getIntervals(entryDate, entryDate, invPeriod, periodStart, true, true)
		# periodArr = getFinancialPeriodArray(entryDate, entryDate, invPeriod, invMonthDay)
		unless currentResident.blank?
			addNewRentalEntry(currentResident, nextInvInterval[0], quantity)
			services = @resident.resident_services.where("rm_resident_services.start_date <= ? AND (rm_resident_services.end_date is null OR rm_resident_services.end_date >= ?)", nextInvInterval[0][1], nextInvInterval[0][0])
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
				teCount = TimeEntry.joins(:spent_for).where(:spent_on => intervalStart, :issue_id => service.issue_id, wk_spent_fors: { spent_for_type: service.resident.resident_type, spent_for_id: service.resident.resident_id }).count
				teEntry = nil
				unless teCount > 0
					quantity = getDuration(intervalStart, intervalEnd, rateHash['rate_per'], 0, false)
					teAttributes = { project_id: issue.project_id, issue_id: service.issue_id, hours: quantity, comments: l(:label_auto_populated_entry), activity_id: getDefultActivity, spent_on: intervalStart, spent_for_attributes: { spent_for_id: service.resident.resident_id, spent_for_type: service.resident.resident_type, spent_on_time: intervalStart.to_datetime } }
					teEntry = TimeEntry.new(teAttributes)
					teEntry.user_id = User.current.id
					teEntry.save
				end
				teEntry
			end
		end
	end
	
	def delAutoGenAmenityEntries(residentAmenity)
		resident = getResidentEntry(residentAmenity.start_date)
		amenityEntries =  TimeEntry.joins(:spent_for).where(:issue_id => residentAmenity.issue_id, wk_spent_fors: { spent_for_id: residentAmenity.resident.resident_id, spent_for_type: residentAmenity.resident.resident_type, invoice_item_id: nil}).where("(time_entries.spent_on < ? AND time_entries.spent_on >= ?) OR (time_entries.spent_on > ? AND time_entries.spent_on <= ?)", residentAmenity.start_date, resident.move_in_date, residentAmenity.end_date, (resident.move_out_date.blank? ? Date.today + 1.year : resident.move_out_date))
		amenityEntries.destroy_all		
	end
	
	def getResidentEntry(resDate)
		resident = RmResident.where("move_in_date <= ? and (move_out_date >= ? OR move_out_date is null)", resDate.beginning_of_day().utc, resDate.beginning_of_day().utc).first
		resident
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
		quantity = 0
		rentInterval.each_with_index do |interval, index|
			intervalStart = interval[0] < invInterval[0] ? invInterval[0] : interval[0]
			intervalEnd = interval[1] > invInterval[1] ? invInterval[1] : interval[1]
			quantity = quantity + getDuration(intervalStart, intervalEnd, assetProperty.rate_per, 0, false)
		end
			# Add entries in the beginning of the interval so here we take intervalStart
			meCount = getMaterialEntries(invInterval[0], rentalIssue, currentResident, nil)
			unless meCount > 0
				meEntry = nil
				meAttributes = { project_id: rentalIssue.project_id, issue_id: rentalIssue.id, comments: l(:label_auto_populated_entry), activity_id: getDefultActivity, spent_on: invInterval[0], quantity: quantity, quantity_returned: nil, org_selling_price: nil, is_deleted: false, org_currency: nil, selling_price: sellPrice, currency: rentCurrency, uom_id: uomId, inventory_item_id: residingOn.id, spent_for_attributes: { spent_for_id: currentResident.resident_id, spent_for_type: currentResident.resident_type, spent_on_time: invInterval[0].to_datetime } }
				meEntry = WkMaterialEntry.new(meAttributes)
				meEntry.user_id = User.current.id
				meEntry.save
			end
		meEntry
		unless meEntry.blank?
			assetProperty.matterial_entry_id = meEntry.id
			assetProperty.save
		end
	end
	
	def getMaterialEntries(intervalStart, rentalIssue, currentResident, invItemId)

		material_entry = WkMaterialEntry.joins(:spent_for).where(:spent_on => intervalStart, :issue_id => rentalIssue.id, wk_spent_fors: { spent_for_type: currentResident.resident_type, spent_for_id: currentResident.resident_id })
		material_entry = material_entry.where(:inventory_item_id => invItemId) unless invItemId.blank?
		material_entry.count
	  end
	
	def getDefultActivity
		activityObj = Enumeration.where(:type => 'TimeEntryActivity')
		activityId = activityObj.blank? ? 0 : activityObj[0].id
		activityId #get from settings
	end
	
	def getResidentServicePeriod(invStartDt, invEndDt, residentId, residentType, issue)
		projectId = getResidentPluginSetting('rm_project').to_i
		#invPeriodHash = {"start" => invStartDt, "end" => invEndDt}
		periodArr = Array.new
		if issue.project_id == projectId
			resObj = RmResident.where(:resident_id => residentId, :resident_type => residentType)
			resObj.each do |resident|
				residentService = resident.resident_services.where("issue_id = ? AND (end_date is null OR end_date >= ?) AND start_date <= ? ", issue.id, invStartDt, invEndDt)
				#unless residentService.blank?
				residentService.each do |resServ|
					startDt = resServ.start_date > invStartDt ? resServ.start_date : invStartDt
					endDt = resServ.end_date.blank? || resServ.end_date > invEndDt ? invEndDt : resServ.end_date
					periodHash = {"start" => startDt, "end" => endDt}
					periodArr << periodHash
				end
			end
		end
		if periodArr.empty?
			periodArr << {"start" => invStartDt, "end" => invEndDt}
		end
		periodArr
	end
	
	def residentMoveIn(resId, resType, moveInDate, moveOutDate, invItemId, apartmentId, bedId, rate, moveInHr, moveInMm)
		errorMsg = ""
		projectId = getResidentPluginSetting('rm_project')
		rentalIssue = getRentalIssue
		unless projectId.blank? || rentalIssue.blank?
			# save Resident
			@rmResidentObj = saveResident(nil, resId, resType, moveInDate,nil, apartmentId, bedId)
			#save Billable Projects for resident
			
			# rentalTrackerId = getResidentPluginSetting('rm_rental_tracker')
			# issueObj = Issue.where(:tracker_id => rentalTrackerId)
			# issueId = issueObj.blank? ? 0 : issueObj[0].id
			
			@activityObj = Enumeration.where(:type => 'TimeEntryActivity')
			saveBillableProjects(nil, projectId, resId, resType, false, true, 'TM')
			#log asset entries for resident
			
			save_material_entry_and_asset_properties(nil, projectId, User.current.id, rentalIssue.id, rate, moveInDate, invItemId, resId, resType, moveInHr, moveInMm)

			#update the rental proration
			rentalProration(@rmResidentObj)
		  else
			errorMsg = l(:label_movein_error_msg)
		  end
		  errorMsg
		end
	  
		  def save_material_entry_and_asset_properties(id, projectId, user_id, rental_issue_id, rate, moveInDate, invItemId, resId, resType, moveInHr, moveInMm)
			  
			  activityId = @activityObj.blank? ? 0 : @activityObj[0].id
			  uomObj = WkMesureUnit.all
			  uomId = uomObj.blank? ? 0 : uomObj[0].id
			  materialObj = saveMatterialEntries(nil, projectId, user_id, rental_issue_id, 1, rate, '$', activityId, moveInDate, invItemId, uomId)
	  
			# update material id for used asset
			invItemObj = WkInventoryItem.find(invItemId)
			assetProperty = invItemObj.asset_property
			assetProperty.matterial_entry_id = materialObj.id
			assetProperty.save
			# save spent for resident
			saveSpentFor(nil, resId, resType, materialObj.id, materialObj.class.name, moveInDate, moveInHr, moveInMm, nil)
			
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
			dateVal = getDateTime(spentDate, spentHr, spentMm, '00')
			resObj.move_out_date = spentDate #dateVal
			resObj.move_out_reason_id = moveOutReason
			resObj.save
			rentalProration(resObj)
			unblockApartBeds(resObj)
			endServiceAmenities(resObj)
		end
	end
	
	def endServiceAmenities(residentObj)
		resContact =  residentObj.resident
		resServices = resContact.resident_services
		currentResServices = resServices.where("rm_resident_services.start_date >= ? AND (rm_resident_services.end_date is null OR rm_resident_services.end_date > ?)", residentObj.move_in_date.to_date, residentObj.move_out_date.to_date)
		currentResServices.each do |resService|
			if resService.start_date > residentObj.move_out_date.to_date
				resService.start_date = residentObj.move_out_date.to_date
				resService.end_date = residentObj.move_out_date.to_date
				delAutoGenAmenityEntries(resService)
				resService.destroy
			else
				resService.end_date = residentObj.move_out_date.to_date
				if resService.save
					updateAutoTEntries(resService, residentObj.move_out_date.to_date)
				end
			end
		end
	end
	
	def updateAutoTEntries(resService, intevalDt)
		if resService.issue.tracker_id == getResidentPluginSetting('rm_amenity_tracker').to_i
			invInterval = getInvoiceInterval(intevalDt, intevalDt, true, true)
			addNewAmenityEntry(resService, invInterval[0], 1)
			delAutoGenAmenityEntries(resService)
		end
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
			frequency = assetObj.rate_per
	  move_in_date = resObj.move_in_date.blank? ? nil : resObj.move_in_date.to_date
	  move_out_date = resObj.move_out_date.blank? ? nil : resObj.move_out_date.to_date
	  updateMaterialEntries(resObj.resident_id, move_out_date, frequency, materialObj, move_in_date, false)
	end
  end

  def updateMaterialEntries(resident_id, move_out_date, frequency, materialObj, move_in_date, isTransfer)

	inv_item_id = WkSpentFor.where(:spent_for_id => resident_id).order("created_at DESC")
			moveInDate = nil
			moveOutDate = nil
			closed_inv_item = nil
			unless inv_item_id.blank? || inv_item_id.drop(1).blank?
				closed_inv_item = inv_item_id.first
				inv_item_id = (inv_item_id.drop(1)).first.invoice_item_id
			end

			if (isTransfer && move_in_date.to_date == move_out_date)
				materialObj.quantity = 0
			else
			
				if !inv_item_id.blank? && !closed_inv_item.blank? && (closed_inv_item.spent_on_time > move_out_date) 
					moveInDate = move_out_date + 1.day
					materialObj.quantity = getFrequencyProration(frequency, moveInDate, moveOutDate) * -1
				else
					moveInDate = move_in_date
					moveOutDate = move_out_date
					materialObj.quantity = getFrequencyProration(frequency, moveInDate, moveOutDate)
				end
			end

			  materialObj.save
			end 
	
	def getMaterialEntryObj(invItemId)
		invItemObj = WkInventoryItem.find(invItemId)
		invItemObj.asset_property
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
			monthStartDay = getMonthStartDay
			endDate = moveOutDate.blank? ? getFinancialPeriodArray(moveInDate, moveInDate, 'm', monthStartDay)[0][1] : moveOutDate
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
	
  def getResidentobj(id)
	resObj = RmResident.find(id.to_i)
  end

end
