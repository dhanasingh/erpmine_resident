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

class RmapartmentController < WkproductitemController

  menu_item	:apartment
  include RmapartmentHelper
  include RmresidentHelper
	include WkassetHelper
	accept_api_auth :index, :edit, :update

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
		headerHash = { 'parent_name' => l(:label_apartment), 'asset_name' => l(:label_bed),   'product_attribute_name' => l(:label_attribute), 'serial_number' => l(:label_serial_number), 'rate' => l(:label_rate), "is_loggable" => l(:label_loggable_asset),  'location_name' => l(:field_location) }
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
		l(:label_attribute_plural)
	end

	def lblAsset
		l(:label_rate)
	end

	def editcomponentLbl
		l(:label_edit_bed)
	end

	def set_filter_session
		filters = [:location_id, :availability, :project_id]
		super(filters)
	end
end
