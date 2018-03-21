class RmresidentController < WkcontactController
  unloadable
	menu_item	:apartment
	
	accept_api_auth :updateresidentservice
	
 

	require_sudo_mode :updateresidentservice
	
	rescue_from Query::StatementInvalid, :with => :query_statement_invalid

	helper :queries
	include QueriesHelper
	
	def index
		entries = nil
		set_filter_session
		retrieve_date_range
		locationId = session[controller_name][:location_id]
		moveInOutId = session[controller_name][:moveinout_id]
		isFarmerResident = session[controller_name][:farmer_resident]	
		retrieve_query(RmResidentQuery, false)
		scope = resident_entry_scope
		
		
		respond_to do |format|
		  format.html {
			@entry_count = scope.count
			@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
			@entries = scope.offset(@entry_pages.offset).limit(@entry_pages.per_page).to_a

			render :layout => !request.xhr?
		  }
		  format.api  {
			@entry_count = scope.count
			@offset, @limit = api_offset_and_limit
			@entries = scope.offset(@offset).limit(@limit)
		  }
		  format.atom {
			entries = scope.limit(Setting.feeds_limit.to_i).reorder("#{RmResident.table_name}.created_on DESC").to_a
			render_feed(entries, :title => l(:label_spent_time))
		  }
		  format.csv {
			# Export all entries
			@entries = scope.to_a
			send_data(query_to_csv(@entries, @query, params), :type => 'text/csv; header=present', :filename => 'timelog.csv')
		  }
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
		if params[:res_service_id].blank?
			@residentService = RmResidentService.new
		else
			@residentService = RmResidentService.find(params[:res_service_id].to_i)
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
end
