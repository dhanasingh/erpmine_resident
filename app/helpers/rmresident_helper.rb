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
include WksurveyHelper 


	WkCrmContact.class_eval do
		has_many :residents, as: :resident, class_name: 'RmResident', dependent: :restrict_with_error
		has_many :resident_services, through: :residents
	end

	WkAccount.class_eval do
		has_many :residents, as: :resident, class_name: 'RmResident', dependent: :restrict_with_error
		has_many :resident_services, through: :residents
	end

	def resident_tabs
		tabs = []
		if params[:controller] == "rmapartment" || params[:controller] == "rmresident" || params[:controller] == "rmperformservice" || params[:controller] == "rmincident" || params[:controller] == "rmevaluation" || params[:controller] == "rmdashboard"
			tabs << {:name => 'rmdashboard', :partial => 'wktime/tab_content', :label => :label_dashboards} if show_resident
			tabs << {:name => 'rmapartment', :partial => 'wktime/tab_content', :label => :label_apartment} if show_apartment
			tabs << {:name => 'rmresident', :partial => 'wktime/tab_content', :label => :label_resident} if show_resident
			tabs << {:name => 'rmperformservice', :partial => 'wktime/tab_content', :label => :label_perform_service} if show_service
			tabs << {:name => 'rmincident', :partial => 'wktime/tab_content', :label => :label_incident}  if show_incident
			tabs << {:name => 'rmevaluation', :partial => 'wktime/tab_content', :label => :label_evaluation}  if show_evaluation
		end
		tabs
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

	def addCareBillingEntries(rm_resident, inv_start, inv_end)
		periods = get_care_billing_periods(rm_resident, inv_start, inv_end)
		periods.each do |period|
			care_svc = rm_resident.resident_services
				.where(issue_id: period[:issue].id)
				.where("start_date <= ? AND (end_date IS NULL OR end_date >= ?)", period[:end_date], period[:start_date])
				.first
			next if care_svc.blank?

			issue     = period[:issue]
			rateHash  = getIssueRateHash(issue)
			seg_start = [period[:start_date].to_date, care_svc.start_date.to_date].max
			seg_end   = care_svc.end_date.present? ? [period[:end_date].to_date, care_svc.end_date.to_date].min : period[:end_date].to_date
			totalHours = getDaysBetween(seg_start, seg_end) * 24
			quantity  = getDuration(seg_start, seg_end, rateHash['rate_per'], totalHours, false)

			existing = TimeEntry.joins(:spent_for)
				.where(
					spent_on: seg_start,
					issue_id: issue.id,
					comments: l(:label_auto_populated_entry),
					wk_spent_fors: { spent_for_type: rm_resident.resident_type, spent_for_id: rm_resident.resident_id }
				)
				.where("wk_spent_fors.invoice_item_id IS NULL")
				.first

			if existing.present?
				existing.hours = quantity
				existing.save!
			else
				te = TimeEntry.new(
					project_id:  issue.project_id,
					issue_id:    issue.id,
					hours:       quantity,
					comments:    l(:label_auto_populated_entry),
					activity_id: getDefultActivity(issue.project),
					spent_on:    seg_start,
					spent_for_attributes: {
						spent_for_id:   rm_resident.resident_id,
						spent_for_type: rm_resident.resident_type,
						spent_on_time:  seg_start.to_datetime
					}
				)
				te.user_id = User.current.id
				te.save!
			end
		end
	end

	# Add Rent, Amenities Entries for next invoice cycle
	def addNewAmenityEntry(service, invInterval, quantity)
		issue = Issue.find(service.issue_id)
		if issue.tracker_id == getResidentPluginSetting('rm_amenity_tracker').to_i || issue.tracker_id == getResidentPluginSetting('rm_care_tracker').to_i
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
				existingEntries = TimeEntry.joins(:spent_for).where(:spent_on => intervalStart, :issue_id => service.issue_id, wk_spent_fors: { spent_for_type: service.resident.resident_type, spent_for_id: service.resident.resident_id })

				teEntry = nil
				totalHours = getDaysBetween(intervalStart, intervalEnd) * 24
				quantity = getDuration(intervalStart, intervalEnd, rateHash['rate_per'], totalHours, false)

				if existingEntries.any?
					existingEntry = existingEntries.first
					if existingEntry.spent_for.present? && existingEntry.spent_for.invoice_item_id.blank?
						existingEntry.hours = quantity
						existingEntry.save!
						teEntry = existingEntry
					end
				else
					teAttributes = { project_id: issue.project_id, issue_id: service.issue_id, hours: quantity, comments: l(:label_auto_populated_entry), activity_id: getDefultActivity(issue.project), spent_on: intervalStart, spent_for_attributes: { spent_for_id: service.resident.resident_id, spent_for_type: service.resident.resident_type, spent_on_time: intervalStart.to_datetime } }
					teEntry = TimeEntry.new(teAttributes)
					teEntry.user_id = User.current.id
					teEntry.save!
				end
				teEntry
			end
		end
	end

	def delAutoGenAmenityEntries(residentAmenity)
		resident = residentAmenity.resident
		return if resident.blank?
		
		amenityEntries =  TimeEntry.joins(:spent_for).where(:issue_id => residentAmenity.issue_id, wk_spent_fors: { spent_for_id: resident.resident_id, spent_for_type: resident.resident_type, invoice_item_id: nil}).where("(time_entries.spent_on < ? AND time_entries.spent_on >= ?) OR (time_entries.spent_on > ? AND time_entries.spent_on <= ?)", residentAmenity.start_date, resident.move_in_date, residentAmenity.end_date, (resident.move_out_date.blank? ? Date.today + 1.year : resident.move_out_date))
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
				meAttributes = { project_id: rentalIssue.project_id, issue_id: rentalIssue.id, comments: l(:label_auto_populated_entry), activity_id: getDefultActivity(rentalIssue.project), spent_on: invInterval[0], quantity: quantity, quantity_returned: nil, org_selling_price: nil, is_deleted: false, org_currency: nil, selling_price: sellPrice, currency: rentCurrency, uom_id: uomId, inventory_item_id: residingOn.id, spent_for_attributes: { spent_for_id: currentResident.resident_id, spent_for_type: currentResident.resident_type, spent_on_time: invInterval[0].to_datetime } }
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

	# `project`, when given, picks an activity actually enabled for that project
	# (system-wide activities can be disabled per-project - see Project#activities).
	# TimeEntry/WkMaterialEntry both reject activity_id values not in project.activities
	# (project != activity's project), so grabbing an arbitrary global activity id here
	# can silently fail the save for projects that don't have it enabled.
	def getDefultActivity(project = nil)
		if project.present?
			activity = project.activities.first
			return activity.id if activity.present?
		end
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

	# Validates that `apartmentId` may host the given resident before a move-in /
	# transfer. Returns an error message (which aborts the move-in) or "" when allowed:
	#   * the apartment's location must be within the current user's permitted scope
	#     (security - a restricted user cannot place residents outside their area), and
	#   * it must fall within the resident's own (contact/account) location - the
	#     apartment's location must equal that location OR be nested under it
	#     (hierarchy allowed), so a resident is never placed outside their location
	#     (data integrity, applies to everyone). Skipped when the resident has no
	#     location of their own.
	def moveInLocationError(residentId, residentType, apartmentId)
		apartmentLoc = WkInventoryItem.find_by(id: apartmentId)&.location_id
		return l(:error_movein_location_not_permitted) unless WkLocation.permitted?(apartmentLoc)
		residentClass = (residentType == 'WkAccount') ? WkAccount : WkCrmContact
		residentLoc = residentClass.unscoped.find_by(id: residentId)&.location_id
		if residentLoc.present? && apartmentLoc.present? && !WkLocation.subtree_ids(residentLoc).include?(apartmentLoc.to_i)
			return l(:error_movein_location_mismatch)
		end
		""
	end

	def residentMoveIn(resId, resType, moveInDate, moveOutDate, invItemId, apartmentId, bedId, rate, moveInHr, moveInMm)
		errorMsg = ""
		projectId = getResidentPluginSetting('rm_project')
		rentalIssue = getRentalIssue
		errorMsg = l(:label_movein_error_msg) if projectId.blank? || rentalIssue.blank?
		errorMsg = moveInLocationError(resId, resType, apartmentId) if errorMsg.blank?
		if errorMsg.blank?
			# save Resident
			errorMsg +=  saveResident(nil, resId, resType, moveInDate,nil, apartmentId, bedId)
			if errorMsg.blank?
				#save Billable Projects for resident
				@activityObj = Enumeration.where(:type => 'TimeEntryActivity')
				saveBillableProjects(nil, projectId, resId, resType, false, true, 'TM')

				#log asset entries for resident
				save_material_entry_and_asset_properties(nil, projectId, User.current.id, rentalIssue.id, rate, moveInDate, invItemId, resId, resType, moveInHr, moveInMm)

				#update the rental proration
				rentalProration(@rmResident)
			end
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
		errorMsg = ""
		if id.blank?
			@rmResident = RmResident.new
		else
			@rmResident = RmResident.find(id.to_i)
		end
		@rmResident.resident_id = residentId
		@rmResident.resident_type = residentType
		@rmResident.move_in_date = moveInDate
		@rmResident.move_out_date = moveOutDate
		@rmResident.apartment_id = invItemId
		@rmResident.bed_id = bedId
		if @rmResident.new_record?
			@rmResident.created_by_user_id = User.current.id
		end
		@rmResident.updated_by_user_id = User.current.id
		unless @rmResident.save
			errorMsg  = errorMsg + @rmResident.errors.full_messages.join("<br>")
		end
		errorMsg
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
		if resService.issue.tracker_id == getResidentPluginSetting('rm_amenity_tracker').to_i || resService.issue.tracker_id == getResidentPluginSetting('rm_care_tracker').to_i
			invInterval = getInvoiceInterval(intevalDt, intevalDt, true, true)
			# Find autogenerated entries and delete
			delAutoGenAmenityEntries(resService)

			addNewAmenityEntry(resService, invInterval[0], 1)
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
			updateMaterialEntries(resObj.resident_id, resObj.move_out_date&.to_date, assetObj.rate_per, assetObj.material_entry, resObj.move_in_date&.to_date, false)
		end
  end

  def updateMaterialEntries(resident_id, move_out_date, frequency, materialObj, move_in_date, isTransfer)
		materialObj ||= WkMaterialEntry.new
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
			if inv_item_id.present? && closed_inv_item.present? && move_out_date.present? && (closed_inv_item.spent_on_time&.to_date > move_out_date)
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

	def getServices(type)
		issueArr = []
		issueObj = nil
		projectId = Setting.plugin_erpmine_resident['rm_project']
		if type == "RS"
			trackerID = Setting.plugin_erpmine_resident['rm_service_tracker']
		else
			trackerID = Setting.plugin_erpmine_resident['rm_amenity_tracker']
		end
		issueObj = Issue.where(:tracker_id => trackerID, :project_id => projectId ) unless trackerID.blank? || projectId.blank?
		issueArr = issueObj.pluck(:subject, :id)  unless issueObj.blank?
		issueArr
	end

	def getCareIssueById(issue_id)
		return nil if issue_id.blank?
		Issue.find_by(id: issue_id.to_i)
	end

	# `project_id`, when given, restricts the match to care-rate Issues that live in the
	# resident's own billing project (e.g. their community/apartment project). This matters
	# because Redmine's TimeEntry validation rejects project_id != issue.project_id
	# (app/models/time_entry.rb), so any care Issue billed for this resident must live in
	# that same project or the auto-generated TimeEntry will never surface on their invoice.
	def getMatchingCareRate(points, project_id = nil)
		care_tracker_id = getResidentPluginSetting('rm_care_tracker')
		return nil if care_tracker_id.blank?
		points_f = points.to_f
		scope = Issue.joins(:wk_issue)
			 .where(:tracker_id => care_tracker_id.to_i)
			 .where('wk_issues.min_points <= ? AND wk_issues.max_points >= ?', points_f, points_f)
		scope = scope.where(:project_id => project_id) if project_id.present?
		scope.first
	end

	def get_care_billing_periods(rm_resident, inv_start_dt, inv_end_dt)
		inv_start = inv_start_dt.to_date
		inv_end   = inv_end_dt.to_date
		periods   = []

		assignments = RmCareBillingAssignment
			.joins(:survey_response)
			.where(rm_resident_id: rm_resident.id)
			.where("rm_care_billing_assignments.effective_date <= ?", inv_end)
			.order("rm_care_billing_assignments.effective_date DESC")
			.select("rm_care_billing_assignments.*, wk_survey_responses.total_points")

		segment_end = inv_end

		assignments.each do |assignment|
			break if segment_end < inv_start

			segment_start = [assignment.effective_date.to_date, inv_start].max
			care_issue    = getMatchingCareRate(assignment.total_points)

			periods << { issue: care_issue, start_date: segment_start, end_date: segment_end } if care_issue.present?

			segment_end = assignment.effective_date.to_date - 1.day
		end

		periods
	end

	def save_care_billing_assignment(rm_resident, survey_response, effective_date)
		return if rm_resident.blank? || survey_response.blank? || effective_date.blank?

		assignment = RmCareBillingAssignment.find_or_initialize_by(
			rm_resident_id:     rm_resident.id,
			survey_response_id: survey_response.id
		)
		assignment.effective_date     = effective_date.to_date
		assignment.updated_by_user_id = User.current.id
		assignment.created_by_user_id = User.current.id if assignment.new_record?

		unless assignment.save
			Rails.logger.error "CareBillingAssignment save failed: #{assignment.errors.full_messages.join(', ')}"
		end
		assignment
	end

	def upsertCareResidentService(rmResident, care_issue, start_date)
		return if rmResident.blank? || care_issue.blank? || start_date.blank?
		start_date = start_date.to_date

		# Clamp start_date to move_in_date — RmResidentService rejects dates before move-in
		move_in = rmResident.move_in_date&.to_date
		start_date = move_in if move_in.present? && start_date < move_in

		# End any existing open care services for a different care issue
		careTrackerId = getResidentPluginSetting('rm_care_tracker').to_i
		existing_services = rmResident.resident_services
										 .joins(:issue)
										 .where(:issues => { :tracker_id => careTrackerId })
										 .where(:end_date => nil)
		existing_services.each do |svc|
			if svc.issue_id != care_issue.id
				svc.end_date = start_date - 1.day
				svc.updated_by_user_id = User.current.id
				svc.save
				# Remove any unbilled care time entries for the old service so they
				# don't double-bill alongside the new care level's entry.
				delAutoGenAmenityEntries(svc)
			end
		end

		# Find or create the care service for this specific care issue
		current_svc = rmResident.resident_services
									 .where(:issue_id => care_issue.id, :end_date => nil)
									 .first
		if current_svc.present?
			if start_date > current_svc.start_date.to_date
				current_svc.start_date = start_date
				current_svc.updated_by_user_id = User.current.id
				unless current_svc.save
					Rails.logger.error "Care service update failed: #{current_svc.errors.full_messages.join(', ')}"
				end
			end
		else
			new_svc = RmResidentService.new
			new_svc.rm_resident_id       = rmResident.id
			new_svc.issue_id             = care_issue.id
			new_svc.start_date           = start_date
			new_svc.created_by_user_id   = User.current.id
			new_svc.updated_by_user_id   = User.current.id
			unless new_svc.save
				Rails.logger.error "Care service create failed: #{new_svc.errors.full_messages.join(', ')}"
			end
		end
	end

	def transferResidentServices(oldResidentId, newResObj, moveInDate)
		return if oldResidentId.blank? || newResObj.blank? || moveInDate.blank?

		oldResObj = RmResident.find_by(id: oldResidentId.to_i)
		return if oldResObj.blank?
		care_tracker_id = getResidentPluginSetting('rm_care_tracker').to_i

		# Clone active resident services that were closed by the move-out process (ONLY for Care entries)
		oldResObj.resident_services.each do |svc|
			if svc.end_date.present? && svc.end_date == oldResObj.move_out_date&.to_date && svc.issue.tracker_id == care_tracker_id
				new_svc = svc.dup
				new_svc.rm_resident_id = newResObj.id
				new_svc.start_date = moveInDate.to_date
				new_svc.end_date = nil
				new_svc.created_by_user_id = User.current.id
				new_svc.updated_by_user_id = User.current.id
				if new_svc.save
					updateAutoTEntries(new_svc, moveInDate.to_date)
				else
					Rails.logger.error "Failed to clone care service during transfer: #{new_svc.errors.full_messages.join(', ')}"
				end
			end
		end

		# Clone the latest Care Billing Assignment
		latest_assignment = RmCareBillingAssignment.where(rm_resident_id: oldResObj.id).order("effective_date DESC").first
		if latest_assignment.present?
			new_assignment = latest_assignment.dup
			new_assignment.rm_resident_id = newResObj.id
			new_assignment.effective_date = moveInDate.to_date
			new_assignment.created_by_user_id = User.current.id
			new_assignment.updated_by_user_id = User.current.id
			unless new_assignment.save
				Rails.logger.error "Failed to clone care billing assignment during transfer: #{new_assignment.errors.full_messages.join(', ')}"
			end
		end
	end

	def show_resident
		validateERPPermission("B_RES_PRVLG") || validateERPPermission("A_RES_PRVLG")
	end

	def show_apartment
		validateERPPermission("B_APT_PRVLG") || validateERPPermission("A_APT_PRVLG")
	end

	def show_service
		validateERPPermission("V_SVC")
	end

	def show_incident
		validateERPPermission("B_INC_PRVLG") || validateERPPermission("A_INC_PRVLG")
	end

	def show_evaluation
		validateERPPermission("B_EVL_PRVLG") || validateERPPermission("A_EVL_PRVLG")
	end

	def show_resident_menu
		show_resident || show_apartment || show_service || show_incident || show_evaluation
	end

end
