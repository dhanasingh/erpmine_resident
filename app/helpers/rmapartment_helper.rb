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

end
