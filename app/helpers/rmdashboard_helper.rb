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

module RmdashboardHelper
	include RmresidentHelper

	def get_graphs_yaml_path
		permittedfiles = []
		ymlFiles = Dir["plugins/erpmine_resident/lib/rmdashboard/*.rb"].map{ |file| file }
		ymlFiles.each do |file|
			fileName = File.basename(file).split("_").first
			nonPermChart = !['graph001', 'graph002', 'graph003', 'graph004'].include?(fileName)
			if(nonPermChart || (fileName == 'graph001' && show_resident) || (fileName == 'graph002' && show_incident) || (fileName == 'graph003' && show_apartment) || (fileName == 'graph004' && show_incident))
					permittedfiles << file
			end
		end
		permittedfiles
	end
end
