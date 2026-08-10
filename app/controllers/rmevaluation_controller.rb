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
  include WksurveyHelper
  before_action :check_resident_status, only: [:survey]

	def ItemLabel
		l(:label_evaluation)
	end

	def newItemLabel
		l(:label_new_evaluation)
	end

	def editItemLabel
		l(:label_edit_evaluation)
	end

	def surveyResponseLabel
		l(:label_evaluation_response)
	end

	def surveyForLabel
		l(:label_evaluation_for)
	end

	# Hide resident-targeted evaluations whose target resident is outside the
	# user's permitted location subtree. Generic (survey_for_id IS NULL) surveys
	# stay visible. nil accessible ids => ADM_ERP/unrestricted => no filtering.
	def surveyList(params)
		surveys = super
		loc_ids = WkLocation.accessible_location_ids
		return surveys unless loc_ids
		in_scope = WkLocation.filter_by_contact_account_location(
			RmResident.left_join_contacts, loc_ids).pluck(:id)
		surveys.where(
			"#{WkSurvey.table_name}.survey_for_id IS NULL OR #{WkSurvey.table_name}.survey_for_id IN (?)",
			in_scope.presence || [-1])
	end

  private

  def check_resident_status
    if params[:surveyForType] == "RmResident" && params[:surveyForID].present?
      res = RmResident.find_by(id: params[:surveyForID].to_i)
      if res && res.move_out_date.present?
        flash[:error] = l(:error_former_resident_eval)
        redirect_to controller: 'rmresident', action: 'edit', rm_resident_id: res.id, tab: 'rmevaluation'
        return false
      end
    end
  end
	
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
        l(:label_resident) => "RmResident"
    }
    survey_types
  end
end
