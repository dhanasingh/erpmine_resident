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

class RmdashboardController < WkbaseController

  menu_item	:apartment
  accept_api_auth :get_graphs, :get_detail_report
  
  def index
    set_filter_session
    retrieve_date_range
  end

  def set_filter_session
    filters = [:period, :from, :to, :location_id]
    super(filters)
	end

  def setDateRange
		retrieve_date_range
		@from = params[:from].to_date if params[:from].present?
		@to = params[:to].to_date if params[:to].present?

		if @from.blank? && @to.blank?
			@to = User.current.today.end_of_month
			@from = User.current.today.end_of_month - 12.months + 1.days
		elsif @from.blank? && @to.present?
			@from = @to - 12.months + 1.days
		elsif @to.blank? && @from.present?
			@to = @from + 12.months - 1.days
		end
		@to = User.current.today if @to > User.current.today
	end

  public

  def graph(path=params[:gPath])
    data = {}
    setDateRange

    begin
      load(path)
      obj = getGraphModule(path)
      data = obj.chart_data({ from: @from, to: @to, location_id: params[:location_id] })

      data[:url] = url_for(data[:url]) if data[:url].present?
    rescue => e
      Rails.logger.error "Rmdashboard graph error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
      data = {error: "404"}
    end

    if params[:gPath].blank?
      data[:gPath] = path
      return(data)
    else
      render(json: data)
    end
	end

  def get_graphs
    graphDetails = (get_graphs_yaml_path.sort).map{|path| graph(path)}
    render json: {graphs: graphDetails}
  end

  def get_detail_report
    path = params[:gPath] if params[:gPath].present?
    data = nil
    setDateRange

    begin
      load(path)
      obj = getGraphModule(path)
      data = obj.get_detail_report({ from: @from, to: @to, location_id: params[:location_id] })
    rescue => e
      Rails.logger.error "Rmdashboard get_detail_report error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
      data = {error: "404"}
    end

		render(json: (data || {}))
	end

  def evaluation_pending_list

    pending_list = []

    surveys = WkSurvey.where(
      survey_for_type: 'RmResident',
      status: ['N', 'O']
    )

    # Restrict the pending list to residents within the user's accessible locations
    # (nil => admin/unrestricted), so a normal user never sees pending evaluations for
    # residents outside their permitted scope.
    allowed_ids = RmResident.ids_in_location_scope

    surveys.each do |survey|

      assigned_ids =
        if survey.survey_for_id.present?
          [survey.survey_for_id]
        else
          allowed_ids.nil? ? RmResident.pluck(:id) : allowed_ids
        end
      assigned_ids &= allowed_ids unless allowed_ids.nil?

      responded_ids =
        WkSurveyResponse.where(
          survey_id: survey.id,
          survey_for_type: 'RmResident'
        ).pluck(:survey_for_id)

      pending_ids = assigned_ids - responded_ids

      pending_ids.each do |resident_id|

        resident = RmResident
                      .left_join_contacts
                      .where("rm_residents.id = ?", resident_id)
                      .select("
                        rm_residents.*,
                        wk_accounts.name as account_name,
                        first_name,
                        last_name
                      ")
                      .first

        resident_name =
          if resident.present?
            resident.account_name.presence ||
            "#{resident.first_name} #{resident.last_name}".strip
          else
            ""
          end

        recur_date =
          if survey.recur? && survey.recur_every.present?
            (survey.created_at.to_date + survey.recur_every.days).strftime("%Y-%m-%d")
          else
            ""
          end

        pending_list << {
          resident_name: resident_name,
          evaluation_name: survey.name,
          response_status: survey.status == "N" ? "New" : "Open",
          recur_date: recur_date
        }

      end

    end

    render json: pending_list

  end

  private

  def getGraphModule(path)
    Object.new.extend(("Rmdashboard::"+(File.basename(path, ".rb")).camelize).constantize)
  end

end
