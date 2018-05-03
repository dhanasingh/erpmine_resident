module RmapartmentHelper
include RmresidentHelper
include WkproductitemHelper
include WktimeHelper
include WkaccountprojectHelper
include WktimeHelper
include WkcrmenumerationHelper
include WkassetdepreciationHelper
include WkpayrollHelper
include WklogmaterialHelper
	
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
	
	def getRentalRate(id)
		rate = 0 
		unless id.blank?
			invItemObj = WkInventoryItem.find(id.to_i)
			rate = invItemObj.asset_property.blank? ? 0 : invItemObj.asset_property.rate unless invItemObj.blank?
		end
		rate
	end

end
