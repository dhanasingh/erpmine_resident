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

module RmapartmentHelper
include RmresidentHelper
include WkproductitemHelper
include WktimeHelper
include WkaccountprojectHelper
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
