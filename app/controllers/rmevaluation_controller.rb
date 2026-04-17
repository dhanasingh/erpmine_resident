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

	accept_api_auth :index
  include WksurveyHelper

	def ItemLabel
		l(:label_evaluation)
	end

	def newItemLabel
		l(:label_new_evaluation)
	end

	def editItemLabel
		l(:label_edit_evaluation)
	end
	
  private
	
  def check_view_perm
    validateERPPermission("B_EVL_PRVLG")
  end

  def check_manage_perm
    validateERPPermission("A_EVL_PRVLG")
  end

	def init_survey
    @survey_ctrl = "rmevaluation"
  end

	def getSurveyFor
    survey_types = {
        "" => '',
        l(:label_resident) => "RmResident"
    }
    survey_types
  end
end
