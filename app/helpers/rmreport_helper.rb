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

module RmreportHelper
  include WktimeHelper

  def hasViewPermission(reportName)
    resident_reports = ['report_move_in_move_out_by_date', 'report_occupancy_report', 'report_occupancy_report_web']
    if resident_reports.include?(reportName.to_s)
      (validateERPPermission("B_CRM_PRVLG") || validateERPPermission("A_CRM_PRVLG")) && isChecked('wktime_enable_crm_module')
    else
      true
    end
  end
end
