class RmapartmentController < WkproductitemController
  unloadable
  menu_item	:apartment
  include RmapartmentHelper

    def newAsset
		true
	end
	
	def getItemType
		'RA'
	end
	
	def showAssetProperties
		true
	end
	
	def newItemLabel
		l(:label_new_apartment)
	end
	
	def editItemLabel
		l(:label_edit_apartment)
	end
  
    def getIventoryListHeader
		headerHash = { 'parent_name' => l(:label_apartment), 'asset_name' => l(:label_bed),   'product_attribute_name' => l(:label_attribute), 'serial_number' => l(:label_serial_number), 'rate' => l(:label_rate), "is_loggable" => l(:label_loggable_asset),  'location_name' => l(:label_location) }
	end
	
	def newcomponentLbl
		l(:label_new_bed)
	end
	
	def showAdditionalInfo
		true
	end
	
	def showInventoryFields
		false
	end
	
	def sectionHeader
		l(:label_beds)
	end
	
	def showProductItem
		false
	end
	
	def loggableAssetLbl
		l(:label_rental_asset)
	end
	
	def loggableRateLbl
		l(:label_rental_rate) 
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
	
	def residentTransfer
		residentMoveOut(params[:resident_id], params[:move_in_date], params[:move_in_hr],  params[:move_in_min])
		invItemId = params[:bed_idM].blank? ? params[:apartment_idM] : params[:bed_idM]
		residentMoveIn(params[:lead_id], 'WkCrmContact', params[:move_in_date], nil, invItemId, params[:apartment_idM], params[:bed_idM], params[:rateM], params[:move_in_hr],  params[:move_in_min])
		
		flash[:notice] = l(:notice_successful_convert)
		redirect_to :controller => 'wkcrmcontact', :action => 'edit', :contact_id => params[:lead_id]
	end
	
	def moveOut
		residentMoveOut(params[:resident_id], params[:move_in_date], params[:move_in_hr],  params[:move_in_min])
		
		flash[:notice] = l(:notice_successful)
		redirect_to :controller => 'rmresident', :action => 'index'
	end
	
	

end
