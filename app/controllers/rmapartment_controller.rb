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

  def index
	session[controller_name] ||= {}
	session[controller_name][:project_id] = resident_project_id
	super
  end

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

	# Apartments are not project-scoped, so hide the Project field/filter.
	def showProjectField
		false
	end

	# Make the apartment name (parent_name column) a link to its edit page,
	# matching the clickable names on other ERPmine list pages.
	def linkParentNameToEdit
		true
	end

	# Beds (asset_name column) are edited via the row's edit icon, so show the
	# bed name as plain text rather than a link, in both the apartment list and
	# the bed list inside the apartment edit page.
	def linkAssetNameToEdit
		false
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
		filters = [:location_id, :availability]
		super(filters)
		session[controller_name][:project_id] = resident_project_id
	end

	def getCsvData(entries)
		rate = getRatePerHash(false)
		asset_type = getAssetTypeHash(false)
		data = entries.map do |entry|
			asset_rate = entry['rate'] ? "#{entry.asset_currency}#{entry['rate']}#{rate[entry['rate_per']]}" : ''

			{
				parent_name: entry['parent_name'].blank? ? entry['asset_name'] : entry['parent_name'],
				asset_name: entry['parent_name'].blank? ? '' : entry['asset_name'],
				product_attribute_name: entry['product_attribute_name'],
				serial_number: entry['serial_number'],
				rate: asset_rate,
				is_loggable: entry.is_loggable?,
				location_name: entry['location_name'] || ''
			}
			end
	end

	def hasDeletePermission
		validateERPPermission("A_APT_PRVLG")
	end

	def update
		params[:project_id] = resident_project_id
		super
	end

  	def resident_project_id
		Setting.plugin_erpmine_resident['rm_project']
	end

	private

	def check_basic_perm
		unless 	validateERPPermission("B_APT_PRVLG") || validateERPPermission("A_APT_PRVLG")
			render_403
			return false
		end
	end

	def check_admin_perm
		unless validateERPPermission("A_APT_PRVLG")
			render_403
			return false
		end
	end

 
end
