class RmapartmentController < WkproductitemController
  unloadable
  menu_item	:apartment
  include RmapartmentHelper
  include RmresidentHelper

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
	
	def lblInventory
		l(:label_attributes)
	end
	
	def lblAsset
		l(:field_rate)
	end
	
	def editcomponentLbl
		l(:label_edit_bed)
	end

	def set_filter_session
		if params[:searchlist] == controller_name
			session[controller_name] = Hash.new if session[controller_name].nil?
			filters = [:location_id, :availability, :project_id]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
	end
end
