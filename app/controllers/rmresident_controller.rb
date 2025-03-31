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

class RmresidentController < WkcrmController

	menu_item	:apartment
	require "active_support"
	accept_api_auth :updateresidentservice, :index, :edit, :update, :movein, :moveInResident, :residentTransfer, :moveOut, :locationApartments, :apartmentBeds, :bedRate



	require_sudo_mode :updateresidentservice

	rescue_from Query::StatementInvalid, :with => :query_statement_invalid

	helper :queries
	include QueriesHelper
	include RmapartmentHelper
	include WkleadHelper
	include WkcrmHelper
	include WkassetHelper

	def index

		entries = nil
		set_filter_session
		retrieve_date_range
		locationId = session[controller_name][:location_id]
		moveInOutId = session[controller_name][:moveinout_id]
		filter_type = session[controller_name].try(:[], :polymorphic_filter)
		contact_id = session[controller_name].try(:[], :contact_id)
		account_id = session[controller_name].try(:[], :account_id)
		parentType = ""
		parentId = ""
		location = WkLocation.where(:is_default => 'true').first
		entries = nil
		entries = RmResident.left_join_contacts
		if moveInOutId == "MI"
			entries = entries.where("rm_residents.move_out_date IS NULL")
		elsif moveInOutId == "MO"
			entries = entries.joins("LEFT JOIN rm_residents AS R2 ON rm_residents.resident_id = R2.resident_id
				AND R2.Move_out_date IS NULL" + get_comp_condition('R2')).where("rm_residents.Move_out_date IS NOT NULL AND R2.resident_id IS NULL")
		end

		# unless residentName.blank?
		# 	entries = entries.where("LOWER(wk_crm_contacts.first_name) like LOWER('%#{residentName}%') OR LOWER(wk_crm_contacts.last_name) like LOWER('%#{residentName}%') OR LOWER(wk_accounts.name) like LOWER('%#{residentName}%')")
		# end
		if filter_type == '2' && !contact_id.blank?
			parentType = 'WkCrmContact'
			parentId = 	contact_id
		elsif filter_type == '2' && contact_id.blank?
			parentType = 'WkCrmContact'
		end

		if filter_type == '3' && !account_id.blank?
			parentType =  'WkAccount'
			parentId = 	account_id
		elsif filter_type == '3' && account_id.blank?
			parentType =  'WkAccount'
		end

		unless parentId.blank?
			entries = entries.where("rm_residents.resident_id = ?", parentId)
		end

		unless parentType.blank?
			entries = entries.where("rm_residents.resident_type = ?", parentType)
		end

		if (!locationId.blank? || !location.blank?) && locationId != "0"
			location_id = !locationId.blank? ? locationId.to_i : location.id.to_i
			entries = entries.where("wk_crm_contacts.location_id = ? OR wk_accounts.location_id = ? ", location_id, location_id)
		end

		if @from.blank? && !@to.blank?
			entries = moveInOutId == "MI" ? entries.where("rm_residents.move_in_date <= ?", @to) : (moveInOutId == "MO" ? entries.where("rm_residents.move_out_date <= ?", @to) : entries)
		elsif !@from.blank? && @to.blank?
			entries = moveInOutId == "MI" ? entries.where("rm_residents.move_in_date >= ?", @from) : (moveInOutId == "MO" ? entries.where("rm_residents.move_out_date >= ?", @from) : entries)
		elsif !@from.blank? && !@to.blank?
			entries = moveInOutId == "MI" ? entries.where("rm_residents.move_in_date BETWEEN ? AND ?", @from, @to) :
			(moveInOutId == "MO" ? entries.where("rm_residents.move_out_date BETWEEN ? AND ?", @from, @to) : entries)
		end
		entries = entries.order((Arel.sql "COALESCE(rm_residents.move_out_date, CURRENT_TIMESTAMP) desc, rm_residents.move_in_date desc "))
		respond_to do |format|
			format.html do
				formPagination(entries)
				render :layout => !request.xhr?
			end
			format.api do
				@resident_entries = entries
			end
		end
	end

	def edit
		@resObj = nil
		unless params[:rm_resident_id].blank?
			@resObj = RmResident.find(params[:rm_resident_id].to_i)
		end
	end

	def update
		errorMsg = ""
		resident_type = !params[:resident_id].blank? ? getResidentobj(params[:resident_id]).resident_type : params[:resident_type]
		action_name = !params[:resident_id].blank? ? 'index' : 'movein'
		resObj = resident_type == "WkAccount" ? accountSave : contactSave
		errorMsg = resObj.errors.full_messages.join("<br>") if !resObj.valid?
		respond_to do |format|
			format.html {
				if errorMsg.blank?
					redirect_to controller: controller_name, action: action_name, tab: "rmresident", res_action: "MI", resident_type_id: resObj.id, resident_type: resident_type
					flash[:notice] = l(:notice_successful_update)
				else
					flash[:error] = errorMsg
					redirect_to controller: controller_name, action: 'edit'
				end
			}
			format.api{
				if errorMsg.blank?
					if params[:resident_id].present?
						render :plain => errorMsg, :layout => nil
					else
						render plain: resObj.id
					end
				else
					@error_messages = errorMsg.split('\n')
					render :template => 'common/error_messages.api', :status => :unprocessable_entity, :layout => nil
				end
			}
		end
	end

	def formPagination(entries)
		@entry_count = entries.count
    setLimitAndOffset()
		@resident_entries = entries.limit(@limit).offset(@offset)
	end

  def setLimitAndOffset
		if api_request?
			@offset, @limit = api_offset_and_limit
			if !params[:limit].blank?
				@limit = params[:limit]
			end
			if !params[:offset].blank?
				@offset = params[:offset]
			end
		else
			@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
			@limit = @entry_pages.per_page
			@offset = @entry_pages.offset
		end
  end

	def resident_entry_scope(options={})
		@query.results_scope(options)
  end

	def getContactType
		'RA'
	end

	def lblNewContact
		l(:label_new_item, l(:label_resident))
	end

	def contactLbl
		l(:label_resident)
	end

	def getContactController
		'wkcrmcontact'
	end

	def newresidentservice
		@residentService = nil
		@contact = nil
		if params[:res_service_id].blank?
			@residentService = RmResidentService.new
		else
			@residentService = RmResidentService.find(params[:res_service_id].to_i)
		end
		unless params[:rm_resident_id].blank?
			@resObj = RmResident.find(params[:rm_resident_id].to_i)
		end
		@serviceType = params[:service_type]

	end

	def residentservicedestroy
		resService = RmResidentService.find(params[:id].to_i)
		resService.destroy
		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default controller: 'rmresident', action: 'edit', rm_resident_id: resService.rm_resident_id
	end

	def updateresidentservice
		errorMsg = ""
		if params[:residentService][:id].blank?
			@residentService = RmResidentService.new
		else
			@residentService = RmResidentService.find(params[:residentService][:id].to_i)
		end
		@residentService.safe_attributes = params[:residentService]
		# @residentService.rm_resident_id = params[:rm_resident_id]
		if @residentService.new_record?
			@residentService.created_by_user_id = User.current.id
		end
		@residentService.updated_by_user_id = User.current.id
		@residentService.save
		errorMsg =  @residentService.errors.full_messages.join("<br>")
		if errorMsg.blank?
			updateAutoTEntries(@residentService, @residentService.start_date)
		end
		respond_to do |format|
			format.html {
				if errorMsg.blank?
					redirect_to controller_name: 'rmresident', action: 'edit' , rm_resident_id: @residentService.rm_resident_id, tab: controller_name
					flash[:notice] = l(:notice_successful_update)
				else
					flash[:error] = errorMsg
					redirect_to controller: 'rmresident', action: 'newresidentservice', service_type: params[:service_type], rm_resident_id: @residentService.rm_resident_id, res_service_id: @residentService.id
				end
			}
			format.api{
				if errorMsg.blank?
					render plain: errorMsg, layout: nil
				else
					@error_messages = errorMsg.split('\n')
					render template: 'common/error_messages.api', status: :unprocessable_entity, layout: nil
				end
			}
		end
	end

	def set_filter_session
		filters = [:period_type, :period, :from, :to, :contact_id, :account_id, :polymorphic_filter, :location_id, :moveinout_id]
		super(filters, {:from => @from, :to => @to})
	end

	# Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[controller_name][:period_type]
		period = session[controller_name][:period]
		fromdate = session[controller_name][:from]
		todate = session[controller_name][:to]
		if (period_type == '1' || (period_type.nil? && !period.nil?))
		  case period.to_s
		  when 'today'
			@from = @to = Date.today
		  when 'yesterday'
			@from = @to = Date.today - 1
		  when 'current_week'
			@from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
			@to = Date.today #@from + 6
		  when 'last_week'
			@from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
			@to = @from + 6
		  when '7_days'
			@from = Date.today - 7
			@to = Date.today
		  when 'current_month'
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = Date.today #(@from >> 1) - 1
		  when 'last_month'
			@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
			@to = (@from >> 1) - 1
		  when '30_days'
			@from = Date.today - 30
			@to = Date.today
		  when 'current_year'
			@from = Date.civil(Date.today.year, 1, 1)
			@to = Date.today
		  end

		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		  begin; @from = fromdate.to_s.to_date unless fromdate.blank?; rescue; end
		  begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		  @free_period = true
		else
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = Date.today #(@from >> 1) - 1
		end

		@from, @to = @to, @from if @from && @to && @from > @to

	end

	def movein
		@leadObj = nil
		@residentObj = nil
		unless params[:lead_id].blank?
			@leadObj = WkLead.find(params[:lead_id].to_i)
		end
		unless params[:resident_type_id].blank?
			@resident_name =  params[:resident_type] == "WkAccount" ?  WkAccount.find(params[:resident_type_id].to_i).name : WkCrmContact.find(params[:resident_type_id].to_i).name
		end
		unless params[:resident_id].blank?
			@residentObj = RmResident.find(params[:resident_id].to_i)
		end
		@resAction = params[:res_action]
	end

	def residentTransfer
		errorMsg = ""
		errorMsg = moveOutValidation
		if errorMsg.blank?
			resident_id = params[:resident_id]
			resObj = getResidentobj(resident_id)
			moveOutDate = params[:move_in_date].to_date
			move_out_date = (moveOutDate > resObj.move_in_date.to_date) ? (moveOutDate - 1.day) : moveOutDate
			invItemId = params[:bed_idM].blank? ? params[:apartment_idM] : params[:bed_idM]
			oldInvItemId = resObj.bed_id.blank? ? resObj.apartment_id : resObj.bed_id
			assetEntryObj = getMaterialEntryObj(oldInvItemId)
			materialEntryObj = assetEntryObj.material_entry || WkMaterialEntry.new
			residentMoveOut(resident_id, move_out_date, params[:move_in_hr],  params[:move_in_min], nil)
			if materialEntryObj.spent_on&.to_date == moveOutDate
				updateMaterialEntries(resident_id, moveOutDate, assetEntryObj.rate_per, materialEntryObj, materialEntryObj.spent_on&.to_date, true)
			end

			errorMsg = residentMoveIn(params[:resTypeID], params[:resType], params[:move_in_date].to_date, nil, invItemId, params[:apartment_idM], params[:bed_idM], params[:rateM], params[:move_in_hr],  params[:move_in_min])
			if errorMsg.blank?
				projectId = getResidentPluginSetting('rm_project')
				rentalIssue = getRentalIssue
				entryDate = (params[:move_in_date].to_date).at_beginning_of_month.next_month
				currentResident = getCurrentResident(params[:resTypeID], entryDate, params[:resType])
				invoice_count =  getMaterialEntries(entryDate, rentalIssue, currentResident, invItemId)

				if invoice_count == 0
					save_material_entry_and_asset_properties(nil, projectId, User.current.id, rentalIssue.id, params[:rateM], entryDate, invItemId, params[:resTypeID], params[:resType], params[:move_in_hr], params[:move_in_min])
					assetObj = getMaterialEntryObj(invItemId)
					materialObj = assetObj.material_entry
					updateMaterialEntries(resident_id, nil, assetObj.rate_per, materialObj, entryDate, false)
				end
			end
		end
		respond_to do |format|
			format.html {
				if errorMsg.blank?
					redirect_to controller: 'rmresident', action: 'edit', rm_resident_id: params[:resident_id]
					flash[:notice] = l(:label_transfer_msg)
				else
					flash[:error] = errorMsg
					redirect_to controller: 'rmresident', action: 'edit', rm_resident_id: params[:resident_id]
				end
			}
			format.api{
				if errorMsg.blank?
					render plain: errorMsg, layout: nil
				else
					@error_messages = errorMsg.split('\n')
					render template: 'common/error_messages.api', status: :unprocessable_entity, layout: nil
				end
			}
		end
	end

	def moveOut
		errorMsg = ""
		errorMsg = moveOutValidation
		# if errorMsg.blank?
			# residentMoveOut(params[:resident_id], params[:move_in_date], params[:move_in_hr],  params[:move_in_min], params[:move_out_reason])
		# end
		if errorMsg.blank?
			residentMoveOut(params[:resident_id], params[:move_in_date], params[:move_in_hr],  params[:move_in_min], params[:move_out_reason])
		end
		respond_to do |format|
			format.html {
				if errorMsg.blank?
					redirect_to controller: 'rmresident', action: 'index', tab: 'rmresident'
					flash[:notice] = l(:label_move_out_msg)
				else
					flash[:error] = errorMsg
					redirect_to controller: 'rmresident', action: 'index', tab: 'rmresident'
				end
			}
			format.api{
				if errorMsg.blank?
					render plain: errorMsg, layout: nil
				else
					@error_messages = errorMsg.split('\n')
					render template: 'common/error_messages.api', status: :unprocessable_entity, layout: nil
				end
			}
		end
	end

	def moveOutValidation
		errorMsg = ""
		resObj = nil
		unless params[:resident_id].blank?
			resObj = RmResident.find(params[:resident_id].to_i)
		end
		if Date.parse(params[:move_in_date]) < Date.parse(resObj.move_in_date.strftime('%F') )
			errorMsg = l(:label_move_out_validate_msg)
		end
		errorMsg
	end

	def getItemType
		'RA'
	end

	def locationApartments
		invItemObj = []
		if !params[:location_id].blank?
			invItemObj = WkInventoryItem.where(:product_type => "RA", :location_id => params[:location_id].to_i, :parent_id => nil).includes(:asset_property).where(:wk_asset_properties => {:matterial_entry_id => nil} )
		else
			invItemObj = WkInventoryItem.where(:product_type => "RA", :parent_id => nil).includes(:asset_property).where.not(:wk_asset_properties => {:matterial_entry_id => nil} )
		end
		respond_to do |format|
			format.text  {
				apartmentArr = ""
				invItemObj.each{|item| apartmentArr << item.id.to_s() + ',' +  (item.asset_property.blank? ? "" : item.asset_property.name.to_s) + "\n" }
				render :plain => apartmentArr
			}
			format.json  {
				apartmentArr = []
				invItemObj.each{|item| apartmentArr << { value: item.id, label: item.asset_property.blank? ? "" : item.asset_property.name.to_s }}
				render(json: apartmentArr)
			}
		end

	end

	def apartmentBeds
		invItemObj = []
		if !params[:apartment_id].blank?
			invItemObj = WkInventoryItem.where(:product_type => "RA", :parent_id => params[:apartment_id].to_i).includes(:asset_property)
			if params[:resMoveIn] == "true"
				invItemObj = invItemObj.where(:wk_asset_properties => {:matterial_entry_id => nil} )
			end
		# else
			# invItemObj = WkInventoryItem.where(:product_type => "RA").includes(:asset_property)
		end
		respond_to do |format|
			format.text  {
				bedArr = ""
				invItemObj.each{|item| bedArr << item.id.to_s() + ',' +  (item.asset_property.blank? ? "" : item.asset_property.name.to_s) + "\n" }
				render :plain => bedArr
			}
			format.json  {
				bedArr = []
				invItemObj.each{|item| bedArr << { value: item.id, label: item.asset_property.blank? ? "" : item.asset_property.name.to_s }}
				render(json: bedArr)
			}
		end
	end

	def bedRate
		invItemObj = []
		bedArr = ""
		invId = params[:bed_id]
		if !params[:apartment_id].blank?
			itemArr = WkInventoryItem.where(:parent_id => params[:apartment_id].to_i).pluck(:id)
			if itemArr.blank?
				invId = params[:apartment_id]
			elsif itemArr.include? params[:bed_id]
				invId = params[:bed_id]
			end
		end

		if !invId.blank?
			invItemObj = WkInventoryItem.where(:product_type => "RA", :id => invId.to_i).includes(:asset_property).where(:wk_asset_properties => {:matterial_entry_id => nil} )
		end
		if invItemObj.blank?
			if !params[:apartment_id].blank?
				invItemObj = WkInventoryItem.where(:product_type => "RA", :id => params[:apartment_id].to_i).includes(:asset_property)#.where(:wk_asset_properties => {:matterial_entry_id => nil} )
			end
		end
		wkasset_helper = Object.new.extend(WkassetHelper)
		rateHash = wkasset_helper.getRatePerHash(false)
		respond_to do |format|
			format.text  {
				bedArr = ""
				invItemObj.each{|item| bedArr << (item.asset_property.blank? ? "" : rateHash[item.asset_property.rate_per].to_s)  + ',' +  (item.asset_property.blank? ? "" : item.asset_property.rate.to_s) }
				render :plain => bedArr
			}
			format.json  {
				bedArr = []
				invItemObj.each{|item| bedArr << { rate: item.asset_property.blank? ? "" : item.asset_property.rate.to_s, rate_per: item.asset_property.blank? ? "" : rateHash[item.asset_property.rate_per].to_s }}
				render(json: bedArr)
			}
		end
	end

	def getAccountType
		'RA'
	end

	def getOrderAccountType
		'RA'
	end

	def getOrderContactType
		'RA'
	end

	def getAccountDDLbl
		l(:field_account)
	end

	def getAdditionalDD
	end

	def getAccountLbl
		l(:field_account)
	end

	def moveInResident
		errorMsg = ""
		resTypeID = params[:resTypeID]
		resType = params[:resType]
		unless params[:lead_id].blank?
			@lead = WkLead.find(params[:lead_id])
			resTypeID = @lead.account.blank? ? @lead.contact_id : @lead.account_id
			resType = @lead.account.blank? ? "WkCrmContact" : "WkAccount"
		end
		moveInDate = params[:move_in_date].to_date
		moveInHr = params[:move_in_hr]
		moveInMm = params[:move_in_min]
		invItemId = params[:bed_idM].blank? ? params[:apartment_idM] : params[:bed_idM]
		errorMsg = residentMoveIn(resTypeID, resType, moveInDate, nil, invItemId, params[:apartment_idM], params[:bed_idM], params[:rateM], moveInHr, moveInMm)
		respond_to do |format|
			format.html {
				if errorMsg.blank?
					if params[:model_name] == "WkLead"
						convert
					else
						convertResident(resType, resTypeID) if params[:model_name] == "WkAccount" || params[:model_name] == "WkCrmContact"
						flash[:notice] = l(:notice_successful_convert)
						redirect_to controller: 'rmresident', action: 'edit', rm_resident_id: @rmResident.id
					end
				else
					flash[:error] = errorMsg
					redirect_to controller: 'rmresident', action: 'index', tab: 'rmresident'
				end
			}
			format.api{
				if errorMsg.blank?
					if params[:model_name] == "WkLead"
						leadConvert(params)
					elsif params[:model_name] == "WkAccount" || params[:model_name] == "WkCrmContact"
						convertResident(resType, resTypeID)
					end
					render plain: errorMsg, layout: nil
				else
					@error_messages = errorMsg.split('\n')
					render template: 'common/error_messages.api', status: :unprocessable_entity, layout: nil
				end
			}
		end
	end

	def convertResident(resType, resTypeID)
		model = resType == "WkAccount" ? WkAccount : WkCrmContact
		modelObj = model.find(resTypeID.to_i)
		resType == "WkAccount" ? modelObj.account_type = 'RA' : modelObj.contact_type = 'RA'
		modelObj.updated_by_user_id = User.current.id
		modelObj.save
	end

	def destroy
		resObj = RmResident.find(params[:rm_resident_id].to_i)
		model = resObj.resident_type == "WkAccount" ? WkAccount : WkCrmContact
		resident = model.find(resObj.resident_id.to_i)
		if resident.destroy
			flash[:notice] = l(:notice_successful_delete)
			delete_documents(params[:rm_resident_id])
		else
			flash[:error] = resident.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
end
