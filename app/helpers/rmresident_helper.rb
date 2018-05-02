module RmresidentHelper
include RmapartmentHelper
include WktimeHelper
include WkassetHelper
include WkpayrollHelper
include WkinvoiceHelper

	WkCrmContact.class_eval do
		has_many :resident_services, as: :resident, :dependent => :restrict_with_error, :class_name => 'RmResidentService'
		has_many :residents, as: :resident, :dependent => :restrict_with_error, :class_name => 'RmResident'
		#has_one :current_resident, as: :resident, :dependent => :restrict_with_error, :class_name => 'RmResident'
		#scope :current_resident, joins(:residents).merge(RmResident.current_resident)
		#scope :status, lambda {|arg| where(arg.blank? ? nil : {:status => arg.to_i}) }
	end

	def residentArray(needBlank)
		resdientArr = Array.new
		residentObj = RmResident.order(:id) 
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
		invPeriod = getInvoiceFrequency #Setting.plugin_redmine_wktime['wktime_generate_invoice_period']
		invDay = getInvWeekStartDay #Setting.plugin_redmine_wktime['wktime_generate_invoice_day']
		invMonthDay = getMonthStartDay #should get from settings
		periodStart = invPeriod == 'W' ? invDay : invMonthDay
		contact = WkCrmContact.find(contactId)
		currentResident = contact.residents.where("rm_residents.move_out_date is null OR rm_residents.move_out_date >= ?", entryDate).first
		nextInvInterval = getIntervals(entryDate, entryDate, invPeriod, periodStart, true, true)
		# periodArr = getFinancialPeriodArray(entryDate, entryDate, invPeriod, invMonthDay)
		unless currentResident.blank?
			addNewRentalEntry(currentResident, nextInvInterval[0], quantity)
			services = contact.resident_services.where("rm_resident_services.end_date is null OR rm_resident_services.end_date >= ?", nextInvInterval[0][1])
			services.each do |service|
				addNewAmenityEntry(service, nextInvInterval[0], quantity)
			end
		end
	end
	
	# Add Rent, Amenities Entries for next invoice cycle
	def addNewAmenityEntry(service, invInterval, quantity)
		issue = Issue.find(service.issue_id)
		rateHash = getIssueRateHash(issue)
		invInterval[0] = service.start_date if  service.start_date > invInterval[0]
		invInterval[1] = service.end_date if !service.end_date.blank? && service.end_date < invInterval[1]
		invDay = getInvWeekStartDay #Setting.plugin_redmine_wktime['wktime_generate_invoice_day']
		invMonthDay = getMonthStartDay #should get from settings
		periodStart = rateHash['rate_per'] == 'W' ? invDay.to_i : invMonthDay
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
	
	def addNewRentalEntry(currentResident, invInterval, quantity)
		residingOn = currentResident.bed.blank? ? currentResident.apartment : currentResident.bed
		assetProperty = residingOn.asset_property
		currentMEntry = assetProperty.material_entry
		sellPrice = currentMEntry.blank? ? assetProperty.rate: currentMEntry.selling_price
		rentCurrency = currentMEntry.blank? ? assetProperty.currency : currentMEntry.currency
		uomId = currentMEntry.blank? ? residingOn.uom_id : currentMEntry.uom_id
		invDay = getInvWeekStartDay #Setting.plugin_redmine_wktime['wktime_generate_invoice_day']
		invMonthDay = getMonthStartDay #should get from settings
		periodStart = assetProperty.rate_per == 'W' ? invDay : invMonthDay
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
end
