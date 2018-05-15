class RmresidentController < WkcontactController
  unloadable
	menu_item	:apartment
	
	accept_api_auth :updateresidentservice
	
 

	require_sudo_mode :updateresidentservice
	
	rescue_from Query::StatementInvalid, :with => :query_statement_invalid

	helper :queries
	include QueriesHelper
	include RmapartmentHelper
	
	
	def index
		
		entries = nil
		set_filter_session
		retrieve_date_range
		locationId = session[controller_name][:location_id]
		moveInOutId = session[controller_name][:moveinout_id]
		residentName = session[controller_name][:resident_name]	
		entries = nil
		entries = RmResident.left_join_contacts
		
		unless residentName.blank?
			entries = entries.where("LOWER(wk_crm_contacts.first_name) like LOWER('%#{residentName}%') OR LOWER(wk_crm_contacts.last_name) like LOWER('%#{residentName}%')")
		end
		unless locationId.blank?
			entries = entries.where("wk_crm_contacts.location_id = #{locationId.to_i} ")
		end
		
		unless moveInOutId.blank?
			if moveInOutId == "MI" && !@from.blank? && !@to.blank?
				entries = entries.where(:move_in_date => @from..@to)
			elsif !@from.blank? && !@to.blank?
				entries = entries.where(:move_out_date => @from..@to)
			end
		end
		formPagination(entries)
	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@resident_entries = entries.order("COALESCE(rm_residents.move_out_date, CURRENT_TIMESTAMP) desc, rm_residents.move_in_date desc ").limit(@limit).offset(@offset)
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
		unless params[:parentId].blank?
			@contact  = WkCrmContact.find(params[:parentId].to_i)
		end
		@residentType = params[:resdient_type]	
			
	end
	
	def updateresidentservice
		if params[:residentService][:id].blank?
			@residentService = RmResidentService.new
		else
			@residentService = RmResidentService.find(params[:residentService][:id].to_i)
		end
		@residentService.safe_attributes = params[:residentService]
		@residentService.resident_type = "WkCrmContact"
		if @residentService.new_record?
			@residentService.created_by_user_id = User.current.id
		end
		@residentService.updated_by_user_id = User.current.id
		if @residentService.save 
			redirect_to :controller_name => 'rmresident', :action => 'edit' , :contact_id => @residentService.resident_id, :tab => controller_name
			flash[:notice] = l(:notice_successful_update)
	   else
			flash[:error] = @residentService.errors.full_messages.join("<br>")
			redirect_to :action => 'newresidentservice', :resdient_type => @residentType 
	   end
	end
	
	def set_filter_session
		if params[:searchlist].blank? && session[controller_name].nil?
			session[controller_name] = {:period_type => params[:period_type], :period => params[:period],:location_id => params[:location_id], :resident_name => params[:resident_name], :from => @from, :to => @to, :moveinout_id => params[:moveinout_id]}
		elsif params[:searchlist] == controller_name
			session[controller_name][:period_type] = params[:period_type]
			session[controller_name][:period] = params[:period]
			session[controller_name][:location_id] = params[:location_id]
			session[controller_name][:resident_name] = params[:resident_name]
			session[controller_name][:from] = params[:from]
			session[controller_name][:to] = params[:to]
			session[controller_name][:moveinout_id] = params[:moveinout_id]
		end
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
		@contactObj = nil
		@residentObj = nil
		unless params[:lead_id].blank?
			@leadObj = WkLead.find(params[:lead_id].to_i)
		end
		unless params[:contact_id].blank?
			@contactObj = WkCrmContact.find(params[:contact_id].to_i)
		end
		unless params[:resident_id].blank?
			@residentObj = RmResident.find(params[:resident_id].to_i)
		end
		@resAction = params[:res_action]
	end
	
	def residentTransfer
		residentMoveOut(params[:resident_id], params[:move_in_date], params[:move_in_hr],  params[:move_in_min], nil)
		invItemId = params[:bed_idM].blank? ? params[:apartment_idM] : params[:bed_idM]
		errorMsg = residentMoveIn(params[:lead_id], 'WkCrmContact', params[:move_in_date], nil, invItemId, params[:apartment_idM], params[:bed_idM], params[:rateM], params[:move_in_hr],  params[:move_in_min])
		
		if errorMsg.blank?
			flash[:notice] = l(:label_transfer_msg)
		else
			flash[:error] = errorMsg
		end
		redirect_to :controller => 'rmresident', :action => 'edit', :contact_id => params[:lead_id]
	end
	
	def moveOut
		residentMoveOut(params[:resident_id], params[:move_in_date], params[:move_in_hr],  params[:move_in_min], params[:move_out_reason])
		
		flash[:notice] = l(:label_move_out_msg)
		redirect_to :controller => 'rmresident', :action => 'index', :tab => 'rmresident'
	end
	
	def getItemType
		'RA'
	end
	
	def locationApartments
		invItemObj = nil
		apartmentArr = ""
		if !params[:location_id].blank?
			invItemObj = WkInventoryItem.where(:product_type => "RA", :location_id => params[:location_id].to_i, :parent_id => nil).includes(:asset_property).where(:wk_asset_properties => {:matterial_entry_id => nil} )
		else
			invItemObj = WkInventoryItem.where(:product_type => "RA", :parent_id => nil).includes(:asset_property).where.not(:wk_asset_properties => {:matterial_entry_id => nil} )
		end
		unless invItemObj.blank?
			invItemObj.each do |item|
				apartmentArr << item.id.to_s() + ',' +  (item.asset_property.blank? ? "" : item.asset_property.name.to_s) + "\n"
			end
		end
		respond_to do |format|
			format.text  { render :text => apartmentArr }
		end
	
	end
	
	def apartmentBeds
		invItemObj = nil
		bedArr = ""
		if !params[:apartment_id].blank?
			invItemObj = WkInventoryItem.where(:product_type => "RA", :parent_id => params[:apartment_id].to_i).includes(:asset_property).where(:wk_asset_properties => {:matterial_entry_id => nil} )
		# else
			# invItemObj = WkInventoryItem.where(:product_type => "RA").includes(:asset_property)
		end
		unless invItemObj.blank?
			invItemObj.each do |item|
				bedArr << item.id.to_s() + ',' +  (item.asset_property.blank? ? "" : item.asset_property.name.to_s) + "\n"
			end
		end
		respond_to do |format|
			format.text  { render :text => bedArr }
		end
	end
	
	def bedRate
		invItemObj = nil
		bedArr = ""
		if !params[:bed_id].blank?
			invItemObj = WkInventoryItem.where(:product_type => "RA", :id => params[:bed_id].to_i).includes(:asset_property).where(:wk_asset_properties => {:matterial_entry_id => nil} )
		end		
		unless invItemObj.blank?
			wkasset_helper = Object.new.extend(WkassetHelper)
			rateHash = wkasset_helper.getRatePerHash(false)
			invItemObj.each do |item|
				bedArr << (item.asset_property.blank? ? "" : rateHash[item.asset_property.rate_per].to_s)  + ',' +  (item.asset_property.blank? ? "" : item.asset_property.rate.to_s) 
			end
		end
		respond_to do |format|
			format.text  { render :text => bedArr }
		end
	end
end
