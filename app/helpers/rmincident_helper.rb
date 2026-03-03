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

module RmincidentHelper
	include RmresidentHelper

	def incident_type_options
		WkCrmEnumeration.where(enum_type: RmIncident::INCIDENT_ENUM_TYPE, active: true)
			.order(position: :asc, name: :asc)
			.map { |entry| [entry.name, entry.id.to_s] }
	end

	def incident_type_label(value)
		return '' if value.blank?

		enum_entry = WkCrmEnumeration.find_by(id: value, enum_type: RmIncident::INCIDENT_ENUM_TYPE)
		enum_entry&.name.to_s
	end

	def incident_status_options
		[
			[l(:label_new), RmIncident::STATUS_NEW],
			[l(:wk_status_submitted), RmIncident::STATUS_SUBMITTED],
			[l(:wk_status_approved), RmIncident::STATUS_APPROVED]
		]
	end

	def incident_status_code(incident)
		incident.workflow_status_code
	end

	def incident_status_label(value)
		status_code = value.is_a?(RmIncident) ? incident_status_code(value) : value.to_s.upcase

		case status_code
		when RmIncident::STATUS_APPROVED
			l(:wk_status_approved)
		when RmIncident::STATUS_SUBMITTED
			l(:wk_status_submitted)
		else
			l(:label_new)
		end
	end

	def incident_status_badge_class(value)
		status_code = value.is_a?(RmIncident) ? incident_status_code(value) : value.to_s.upcase

		case status_code
		when RmIncident::STATUS_APPROVED
			'is-approved'
		when RmIncident::STATUS_SUBMITTED
			'is-submitted'
		else
			'is-new'
		end
	end

	# ── PDF colour palette (B&W-print-safe) ────────────────────────────────────
	PDF_COLOR_BRAND     = [40,  40,  40]  # charcoal – title banner
	PDF_COLOR_HEADER_BG = [70,  70,  70]  # dark gray – section headers, prints clearly in B&W
	PDF_COLOR_HEADER_FG = [255, 255, 255] # white text on dark headers
	PDF_COLOR_ROW_ALT   = [240, 240, 240] # neutral light gray alternate rows
	PDF_COLOR_LABEL_FG  = [80,  80,  80]  # medium gray labels
	PDF_COLOR_VALUE_FG  = [0,   0,   0]   # black values
	PDF_COLOR_BORDER    = [180, 180, 180] # medium gray border
	PDF_COLOR_TITLE_FG  = [255, 255, 255]
	PDF_COLOR_META_FG   = [50,  50,  50]

	def incident_to_pdf(incident, resident_info = {})
		pdf = Redmine::Export::PDF::ITCPDF.new(current_language)
		pdf.set_title("#{l(:label_incident_tracking)} ##{incident.id}")
		pdf.alias_nb_pages
		pdf.set_print_footer(false)
		pdf.add_page

		status_label = incident_status_label(incident)

		# ── Title banner ────────────────────────────────────────────────────────
		pdf.SetFillColor(*PDF_COLOR_BRAND)
		pdf.SetTextColor(*PDF_COLOR_TITLE_FG)
		pdf.SetDrawColor(*PDF_COLOR_BRAND)
		pdf.SetFontStyle('B', 14)
		pdf.RDMCell(190, 10, "#{l(:label_incident_tracking)} ##{incident.id}", 0, 1, 'L', 1)

		# Status meta row
		pdf.SetFillColor(230, 230, 230)
		pdf.SetTextColor(*PDF_COLOR_META_FG)
		pdf.SetFontStyle('', 8)
		pdf.RDMCell(190, 6, "  #{l(:field_status)}: #{status_label}", 0, 1, 'L', 1)
		pdf.ln(3)

		# ── Resident Detail ──────────────────────────────────────────────────────
		incident_pdf_section_header(pdf, l(:label_resident_detail))
		apartment_val = [resident_info[:apartment], resident_info[:bed]].reject(&:blank?).join(' ')
		incident_pdf_two_col_rows(pdf, [
			[l(:label_resident),    incident.rm_resident&.name],
			[l(:label_apartment),   apartment_val]
		], [
			[l(:field_move_in_date), resident_info[:move_in_date]],
			[l(:field_location),    resident_info[:location]]
		])
		pdf.ln(3)

		# ── Incident Details ────────────────────────────────────────────────────
		incident_pdf_section_header(pdf, l(:label_incident_details))
		incident_pdf_two_col_rows(pdf, [
			[l(:field_incident_datetime), incident.incident_datetime.present? ? format_time(incident.incident_datetime) : nil]
		], [
			[l(:field_location), incident.location]
		])
		incident_pdf_full_row(pdf, l(:field_incident_type), incident_type_label(incident.incident_type_id), 1)
		incident_pdf_full_row(pdf, l(:field_description), incident.desc)
		pdf.ln(3)

		# ── Witnesses ───────────────────────────────────────────────────────────
		incident_pdf_section_header(pdf, l(:label_witnesses))
		incident_pdf_full_row(pdf, l(:field_witnesses), incident.witnesses)
		pdf.ln(3)

		# ── Actions & Impact ────────────────────────────────────────────────────
		incident_pdf_section_header(pdf, l(:label_actions))
		[
			[l(:field_injuries_or_damages),  incident.injuries],
			[l(:field_immediate_actions),    incident.imm_action],
			[l(:field_additional_notes),     incident.notes],
			[l(:field_follow_up_actions),    incident.follow_up],
			[l(:field_preventive_measures),  incident.prev_action]
		].each_with_index do |(label, value), idx|
			incident_pdf_full_row(pdf, label, value, idx)
		end
		pdf.ln(3)

		# ── Reporting & Signatures ──────────────────────────────────────────────
		submitted_status = incident.wkstatus.where(status: 'S').order(status_date: :desc).first
		approved_status  = incident.wkstatus.where(status: 'A').order(status_date: :desc).first
		submitted_by = User.find_by(id: submitted_status&.status_by_id)&.name
		approved_by  = User.find_by(id: approved_status&.status_by_id)&.name

		incident_pdf_section_header(pdf, l(:label_reporting_signatures))

		# Name row full-width
		incident_pdf_full_row(pdf, l(:field_reporting_staff_name), incident.rpt_name, 0)

		# Two side-by-side signature panels
		submitted_date = submitted_status&.status_date.present? ? format_time(submitted_status.status_date) : nil
		approved_date  = approved_status&.status_date.present?  ? format_time(approved_status.status_date)  : nil
		incident_pdf_signature_panels(pdf,
			l(:field_reporting_staff_signature), submitted_by,  "#{l(:wk_status_submitted)} #{l(:label_date)}", submitted_date,
			l(:field_approval_staff_signature),  approved_by,   "#{l(:wk_status_approved)} #{l(:label_date)}",  approved_date
		)
		pdf.ln(3)

		pdf.output
	end

	private

	# Dark blue section heading bar
	def incident_pdf_section_header(pdf, title)
		pdf.SetFillColor(*PDF_COLOR_HEADER_BG)
		pdf.SetTextColor(*PDF_COLOR_HEADER_FG)
		pdf.SetDrawColor(*PDF_COLOR_HEADER_BG)
		pdf.SetFontStyle('B', 9)
		pdf.RDMCell(190, 6, "  #{title.upcase}", 0, 1, 'L', 1)
		pdf.SetDrawColor(*PDF_COLOR_BORDER)
	end

	# Full-width label + value row with alternating fill
	def incident_pdf_full_row(pdf, label, value, idx = 0)
		use_fill = (idx % 2 == 0)
		pdf.SetFillColor(*(use_fill ? PDF_COLOR_ROW_ALT : [255, 255, 255]))
		h = [pdf.get_string_height(130, incident_pdf_value(value)), 5].max

		pdf.SetTextColor(*PDF_COLOR_LABEL_FG)
		pdf.SetFontStyle('B', 8)
		pdf.RDMMultiCell(55, h, "  #{label}:", 0, 'L', use_fill ? 1 : 0, 0)

		pdf.SetTextColor(*PDF_COLOR_VALUE_FG)
		pdf.SetFontStyle('', 9)
		pdf.RDMMultiCell(135, h, incident_pdf_value(value), 0, 'L', use_fill ? 1 : 0, 1)

		pdf.SetTextColor(*PDF_COLOR_BORDER)
		pdf.RDMCell(190, 0, '', 'T', 1)
	end

	# Two-column row pairs: left_pairs and right_pairs are [[label, value], ...]
	def incident_pdf_two_col_rows(pdf, left_pairs, right_pairs)
		base_x = pdf.get_x
		rows = [left_pairs.size, right_pairs.size].max
		rows.times do |i|
			l_label, l_val = left_pairs[i] || ['', nil]
			r_label, r_val = right_pairs[i] || ['', nil]

			use_fill = (i % 2 == 0)
			fill_color = use_fill ? PDF_COLOR_ROW_ALT : [255, 255, 255]
			pdf.SetFillColor(*fill_color)

			lv_str = incident_pdf_value(l_val)
			rv_str = incident_pdf_value(r_val)
			h = [
				pdf.get_string_height(27, "#{l_label}:"),
				pdf.get_string_height(27, "#{r_label}:"),
				pdf.get_string_height(60, lv_str),
				pdf.get_string_height(60, rv_str),
				5
			].max

			# left label
			pdf.SetTextColor(*PDF_COLOR_LABEL_FG)
			pdf.SetFontStyle('B', 8)
			pdf.RDMMultiCell(30, h, "  #{l_label}:", 0, 'L', use_fill ? 1 : 0, 0)
			# left value
			pdf.SetTextColor(*PDF_COLOR_VALUE_FG)
			pdf.SetFontStyle('', 9)
			pdf.RDMMultiCell(62, h, lv_str, 0, 'L', use_fill ? 1 : 0, 0)
			# right label
			pdf.SetTextColor(*PDF_COLOR_LABEL_FG)
			pdf.SetFontStyle('B', 8)
			pdf.RDMMultiCell(30, h, "  #{r_label}:", 0, 'L', use_fill ? 1 : 0, 0)
			# right value
			pdf.SetTextColor(*PDF_COLOR_VALUE_FG)
			pdf.SetFontStyle('', 9)
			pdf.RDMMultiCell(62, h, rv_str, 0, 'L', use_fill ? 1 : 0, 1)

			# thin separator line
			pdf.set_x(base_x)
			pdf.SetDrawColor(*PDF_COLOR_BORDER)
			pdf.RDMCell(190, 0, '', 'T', 1)
			pdf.set_x(base_x)
		end
	end

	def incident_pdf_value(value)
		value.present? ? value.to_s : '-'
	end

	# Two side-by-side signature panels — simple horizontal line style
	def incident_pdf_signature_panels(pdf, l_role, l_name, l_date_label, l_date, r_role, r_name, r_date_label, r_date)
		base_x  = pdf.get_x
		panel_w = 92
		gap     = 6

		pdf.ln(6)

		# ── Name (italic) above the line ─────────────────────────────────────────
		pdf.SetFontStyle('I', 11)
		pdf.SetTextColor(*PDF_COLOR_VALUE_FG)
		pdf.RDMCell(panel_w, 7, "  #{l_name.presence || ''}", 0, 0, 'L', 0)
		pdf.RDMCell(gap,     7, '', 0, 0)
		pdf.RDMCell(panel_w, 7, "#{r_name.presence || ''}  ", 0, 1, 'R', 0)
		pdf.set_x(base_x)

		# ── Horizontal rule ───────────────────────────────────────────────────────
		pdf.SetDrawColor(*PDF_COLOR_BORDER)
		y = pdf.get_y
		pdf.Line(base_x,                    y, base_x + panel_w,                   y)
		pdf.Line(base_x + panel_w + gap,    y, base_x + panel_w + gap + panel_w,   y)
		pdf.ln(2)
		pdf.set_x(base_x)

		# ── Role label ────────────────────────────────────────────────────────────
		pdf.SetFontStyle('B', 8)
		pdf.SetTextColor(*PDF_COLOR_LABEL_FG)
		pdf.RDMCell(panel_w, 5, "  #{l_role}", 0, 0, 'L', 0)
		pdf.RDMCell(gap,     5, '', 0, 0)
		pdf.RDMCell(panel_w, 5, "#{r_role}  ", 0, 1, 'R', 0)
		pdf.set_x(base_x)

		# ── Date ──────────────────────────────────────────────────────────────────
		pdf.SetFontStyle('', 8)
		l_date_str = l_date.present? ? l_date : '-'
		r_date_str = r_date.present? ? r_date : '-'
		pdf.RDMCell(panel_w, 5, "  #{l_date_label}: #{l_date_str}", 0, 0, 'L', 0)
		pdf.RDMCell(gap,     5, '', 0, 0)
		pdf.RDMCell(panel_w, 5, "#{r_date_label}: #{r_date_str}  ", 0, 1, 'R', 0)
		pdf.set_x(base_x)
	end
end
