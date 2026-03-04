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

class RmincidentController < WkcrmController

	menu_item :apartment
	accept_api_auth :index, :edit, :update, :destroy, :get_resident_info, :get_residents_by_location
	include RmresidentHelper
	helper_method :approvePermission

	def index
		set_filter_session
		ensure_default_period_filter
		retrieve_date_range

		@selected_resident_id = session[controller_name].try(:[], :rm_resident_id)
		@selected_resident_id = params[:rm_resident_id] if params[:rm_resident_id].present?
		@selected_location = session[controller_name].try(:[], :location)
		@selected_incident_type = session[controller_name].try(:[], :incident_type)
		@selected_incident_status = session[controller_name].try(:[], :incident_status)

		@rm_resident = RmResident.find_by(id: @selected_resident_id) if @selected_resident_id.present?
		load_residents
		@location_options = WkLocation.order(:name).pluck(:name)

		entries = RmIncident.includes(:rm_resident, :reporting_staff_user)
		entries = entries.where(rm_resident_id: @selected_resident_id) if @selected_resident_id.present?
		entries = entries.where("LOWER(rm_incidents.location) = LOWER(?)", @selected_location) if @selected_location.present?
		entries = entries.where(incident_type_id: @selected_incident_type) if @selected_incident_type.present?
		entries = apply_incident_status_filter(entries, @selected_incident_status) if @selected_incident_status.present?
		entries = entries.where("rm_incidents.incident_date >= ?", @from.beginning_of_day) if @from.present?
		entries = entries.where("rm_incidents.incident_date <= ?", @to.end_of_day) if @to.present?
		entries = entries.order(Arel.sql "incident_date DESC, id DESC")

		respond_to do |format|
			format.html do
				@entry_count = entries.count
				@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
				@incident_entries = entries.limit(@entry_pages.per_page).offset(@entry_pages.offset)
			end
			format.csv do
				send_data(
					incident_list_to_csv(entries),
					type: 'text/csv; header=present',
					filename: "incident-list-#{User.current&.login || 'export'}-#{Date.today}.csv"
				)
			end
			format.api do
				@entry_count = entries.count
				set_limit_and_offset
				@incident_entries = entries.limit(@limit).offset(@offset)
			end
		end
	end

	def edit
		@selected_resident_location = params[:resident_location].to_s
		load_reporting_staff_options
		if params[:id].present?
			@incident = RmIncident.find(params[:id])
			@rm_resident = @incident.rm_resident
			load_status_signatures(@incident)
		else
			@incident = RmIncident.new
			if @incident.reported_by_id.blank?
				@incident.reported_by_id = User.current.id
			end
			@rm_resident = RmResident.find(params[:rm_resident_id]) if params[:rm_resident_id].present?
			@incident.rm_resident_id = @rm_resident.id if @rm_resident.present?
		end

		resident_locked = @incident.persisted? && @rm_resident.present?
		if resident_locked
			@selected_resident_info = resident_info_hash(@rm_resident)
		else
			load_residents
			selected_resident = @rm_resident.presence || RmResident.find_by(id: @incident.rm_resident_id)
			@selected_resident_info = resident_info_hash(selected_resident)
		end

		respond_to do |format|
			format.html
			format.api
			format.pdf do
				send_data(
					helpers.incident_to_pdf(@incident, @selected_resident_info || {}),
					type: 'application/pdf',
					filename: "incident-#{@incident.id || 'new'}.pdf"
				)
			end
		end
	end

	def update
		approve_requested = params[:approve_incident].present?
		@incident = params[:incident][:id].present? ? RmIncident.find(params[:incident][:id]) : RmIncident.new
			if approve_requested && (!approvePermission(@incident) || @incident.new_record?)
			render_403
			return false
		end

		if incident_approved?(@incident)
			respond_to do |format|
				format.html do
					flash[:error] = 'Approved incident is read-only.'
					redirect_to controller: 'rmincident', action: 'edit', id: @incident.id, rm_resident_id: @incident.rm_resident_id
				end
				format.api do
					@error_messages = ['Approved incident is read-only.']
					render template: 'common/error_messages', format: [:api], status: :unprocessable_entity, layout: nil
				end
			end
			return
		end

		already_submitted = incident_submitted?(@incident)
		if already_submitted && !approve_requested
			respond_to do |format|
				format.html do
					flash[:error] = 'Submitted incident can only be approved.'
					redirect_to controller: 'rmincident', action: 'edit', id: @incident.id, rm_resident_id: @incident.rm_resident_id
				end
				format.api do
					@error_messages = ['Submitted incident can only be approved.']
					render template: 'common/error_messages', format: [:api], status: :unprocessable_entity, layout: nil
				end
			end
			return
		end

		if already_submitted && params[:incident].present?
			params[:incident]&.delete('reported_by_id') || params[:incident]&.delete(:reported_by_id)
		end

		@incident.safe_attributes = params[:incident] if !already_submitted || approvePermission(@incident)
		@incident.created_by_id = User.current.id if @incident.new_record?
		@incident.updated_by_id = User.current.id

		if @incident.save
			record_incident_status(@incident, approve_requested ? 'A' : 'S')
			respond_to do |format|
				format.html do
					flash[:notice] = l(:notice_successful_update)
					redirect_to controller: 'rmincident', action: 'index', tab: 'rmincident', rm_resident_id: @incident.rm_resident_id
				end
				format.api { render plain: @incident.id }
			end
		else
			@selected_resident_location = params[:resident_location].to_s
			load_reporting_staff_options
			@rm_resident = @incident.rm_resident
			resident_locked = @incident.persisted? && @rm_resident.present?
			if resident_locked
				@selected_resident_info = resident_info_hash(@rm_resident)
			else
				load_residents
				selected_resident = @rm_resident.presence || RmResident.find_by(id: @incident.rm_resident_id)
				@selected_resident_info = resident_info_hash(selected_resident)
			end
			load_status_signatures(@incident) if @incident.persisted?
			respond_to do |format|
				format.html do
					flash.now[:error] = @incident.errors.full_messages.join('<br>')
					render action: 'edit'
				end
				format.api do
					@error_messages = @incident.errors.full_messages
					render template: 'common/error_messages', format: [:api], status: :unprocessable_entity, layout: nil
				end
			end
		end
	end

	def destroy
		incident = RmIncident.find(params[:id])
		rm_resident_id = incident.rm_resident_id
		incident.destroy
		respond_to do |format|
			format.html do
				flash[:notice] = l(:notice_successful_delete)
				redirect_to controller: 'rmincident', action: 'index', tab: 'rmincident', rm_resident_id: rm_resident_id
			end
			format.api { render plain: '' }
		end
	end

	def get_resident_info
		resident = RmResident.find_by(id: params[:rm_resident_id])
		render json: resident_info_hash(resident)
	end

	def get_residents_by_location
		location_id = params[:location_id].presence
		residents = active_residents_scope
		if location_id.present?
			residents = residents.where(
				"#{WkCrmContact.table_name}.location_id = :location_id OR #{WkAccount.table_name}.location_id = :location_id",
				location_id: location_id.to_i
			)
		end
		render json: residents.filter_map { |r| r.name.present? ? { id: r.id, name: r.name } : nil }
	end

	private

	def incident_list_to_csv(entries)
		headers = {
			incident_date: l(:field_incident_date),
			resident_name: l(:field_resident),
			incident_type: l(:field_incident_type),
			location: l(:field_location),
			status: l(:field_status),
			reporting_staff: l(:field_reporting_staff_name)
		}

		rows = entries.to_a.map do |entry|
			{
				incident_date: entry.incident_date.present? ? format_time(entry.incident_date) : '',
				resident_name: entry.rm_resident&.name,
				incident_type: helpers.incident_type_label(entry.incident_type_id),
				location: entry.location,
				status: helpers.incident_status_label(entry),
				reporting_staff: entry.reporting_staff_user&.name
			}
		end

		csv_export(headers: headers, data: rows)
	end

	def set_limit_and_offset
		@offset, @limit = api_offset_and_limit
		@limit = params[:limit] if params[:limit].present?
		@offset = params[:offset] if params[:offset].present?
	end

	def ensure_default_period_filter
		session[controller_name] ||= {}
		period_type = session[controller_name][:period_type]
		period = session[controller_name][:period]
		fromdate = session[controller_name][:from]
		todate = session[controller_name][:to]

		return if period_type.present? || period.present? || fromdate.present? || todate.present?

		session[controller_name][:period_type] = '1'
		session[controller_name][:period] = 'current_month'
	end

	def set_filter_session
		filters = [:period_type, :period, :from, :to, :rm_resident_id, :location, :incident_type, :incident_status]
		super(filters, {:from => @from, :to => @to})
	end

	def load_residents
		@resident_options = active_residents_scope
			.filter_map { |r| r.name.present? ? [r.name, r.id] : nil }
		@resident_location_options = WkLocation.order(:name).pluck(:name, :id)
	end

	def load_reporting_staff_options
		users = getReportUsers(User.current.id)
		users = [User.current] if users.blank?
		@reporting_staff_options = users.map { |user| [user.name, user.id] }
	end

	def active_residents_scope
		RmResident.left_join_contacts
			.where(move_out_date: nil)
			.includes(:resident)
	end

	def resident_info_hash(resident)
		return { location: '', apartment: '' } unless resident
		resident_record = case resident.resident_type
		when 'WkCrmContact'
			WkCrmContact.find_by(id: resident.resident_id)
		when 'WkAccount'
			WkAccount.find_by(id: resident.resident_id)
		else
			nil
		end
		{
			move_in_date: resident.move_in_date&.strftime('%Y-%m-%d').to_s,
			location: resident_record&.respond_to?(:location) ? resident_record.location&.name.to_s : '',
			apartment: resident.apartment&.asset_property&.name.to_s,
			bed: resident.bed&.asset_property&.name.to_s
		}
	end

	def load_status_signatures(incident)
		submitted_status = incident.wkstatus.where(status: 'S').order(status_date: :desc).first
		approved_status = incident.wkstatus.where(status: 'A').order(status_date: :desc).first
		@submitted_by = User.find_by(id: submitted_status&.status_by_id)&.name
		@approved_by = User.find_by(id: approved_status&.status_by_id)&.name
		@submitted_on = submitted_status&.status_date
		@approved_on = approved_status&.status_date
	end

	def record_incident_status(incident, status_code)
		status_code = status_code.to_s.upcase
		raise ArgumentError, "Unsupported incident status code: #{status_code}" unless [RmIncident::STATUS_SUBMITTED, RmIncident::STATUS_APPROVED].include?(status_code)

		last_status = incident.wkstatus.order(status_date: :desc).first
		return if last_status.present? && last_status.status.to_s.upcase == status_code

		incident.wkstatus.create!(
			status_for_type: 'RmIncident',
			status: status_code,
			status_date: Time.current,
			status_by_id: User.current.id
		)
	end

	def approvePermission(incident = nil)
		return true if validateERPPermission('A_CRM_PRVLG')
	
		reporting_user_id = incident&.try(:reported_by_id)
		return true if reporting_user_id && respond_to?(:isSupervisorForUser) && isSupervisorForUser(reporting_user_id)
	
		false
	end

	def incident_submitted?(incident)
		return false if incident.new_record?
		incident.wkstatus.where(status: RmIncident::STATUS_SUBMITTED).exists?
	end

	def incident_approved?(incident)
		return false if incident.new_record?
		incident.wkstatus.where(status: RmIncident::STATUS_APPROVED).exists?
	end

	def apply_incident_status_filter(entries, status_code)
		status_table = WkStatus.table_name
		status_code = status_code.to_s.upcase

		case status_code
		when RmIncident::STATUS_APPROVED
			entries.where(
				"EXISTS (SELECT 1 FROM #{status_table} ws WHERE ws.status_for_type = ? AND ws.status_for_id = rm_incidents.id AND ws.status = ?)",
				'RmIncident', RmIncident::STATUS_APPROVED
			)
		when RmIncident::STATUS_SUBMITTED
			entries.where(
				"EXISTS (SELECT 1 FROM #{status_table} ws WHERE ws.status_for_type = ? AND ws.status_for_id = rm_incidents.id AND ws.status = ?)",
				'RmIncident', RmIncident::STATUS_SUBMITTED
			).where(
				"NOT EXISTS (SELECT 1 FROM #{status_table} ws WHERE ws.status_for_type = ? AND ws.status_for_id = rm_incidents.id AND ws.status = ?)",
				'RmIncident', RmIncident::STATUS_APPROVED
			)
		when RmIncident::STATUS_NEW
			entries.where(
				"NOT EXISTS (SELECT 1 FROM #{status_table} ws WHERE ws.status_for_type = ? AND ws.status_for_id = rm_incidents.id AND ws.status IN (?, ?))",
				'RmIncident', RmIncident::STATUS_SUBMITTED, RmIncident::STATUS_APPROVED
			)
		else
			raise ArgumentError, "Unsupported incident status filter: #{status_code}"
		end
	end
end
