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

class RmevaluationController < WksurveyController

  menu_item	:apartment
	accept_api_auth :index
	before_action :require_login, :survey_url_validation, :check_perm_and_redirect
  before_action :check_eval_perm_and_redirect

	def ItemLabel
		l(:label_evaluation)
	end

	def newItemLabel
		l(:label_new_evaluation)
	end

	def editItemLabel
		l(:label_edit_evaluation)
	end

	def check_eval_perm_and_redirect
		unless validateERPPermission("B_CRM_PRVLG") || validateERPPermission("A_CRM_PRVLG")
			render_403
			return false
		end
	end
end
