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

module RmperformserviceHelper
include RmapartmentHelper
  def getResIssues
    issues = Array.new
    allIssues = Issue.where(:project_id => controller.getDefultProject)
    issues << [ "", ""] if !Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].blank? &&
    Setting.plugin_redmine_wktime['wktime_allow_blank_issue'].to_i == 1
    allIssues.each do |i|
      issues << [ i.to_s , i.id ]
    end
    issues
  end
end
