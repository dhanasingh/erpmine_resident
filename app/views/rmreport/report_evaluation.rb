module ReportEvaluation
	include WkreportHelper

	def calcReportData(user_id, group_id, projId, from, to, location_id=nil, evaluation_id=nil)

        if evaluation_id.blank? || evaluation_id.to_s == "0"
            return {
                error: "No Evaluation Selected"
            }
        end

        survey = WkSurvey.find_by(id: evaluation_id)

        if survey.blank?
            return {
                error: "Evaluation Not Found"
            }
        end

        residents = []

        # Question structure, ordered/grouped exactly like the on-screen survey
        # (_response_detail.html.erb), preloaded once so building each resident's
        # detail doesn't re-query per response.
        questions_by_group = survey.wk_survey_questions
            .includes(:wk_survey_que_group, :wk_survey_choices)
            .order("wk_survey_questions.lft, wk_survey_questions.id")
            .group_by { |q| q.wk_survey_que_group }

        # collect all responses
        survey.wk_survey_responses.each do |response|

            resident_name = ""

            residentObj = RmResident.left_join_contacts
                .where("rm_residents.id = ?", response.survey_for_id)
                .select("wk_accounts.name as account_name, first_name, last_name, resident_type, COALESCE(wk_crm_contacts.location_id, wk_accounts.location_id) as resident_location_id")
                .first

            # Location filter: when a location is selected, include responses whose
            # resident's (contact/account) location is that location OR any descendant
            # (subtree match), so picking a parent zone returns everyone beneath it.
            # Uses the same location dimension as the resident list and permission scope.
            if location_id.present? && location_id.to_s != "0"
                loc_ids = WkLocation.subtree_ids(location_id)
                next if residentObj.nil? || !loc_ids.include?(residentObj.resident_location_id.to_i)
            end

            if residentObj.present?

                if residentObj.resident_type == "WkAccount"
                    resident_name = residentObj.account_name
                else
                    resident_name = "#{residentObj.first_name} #{residentObj.last_name}"
                end
            end

            questions = []

            response.wk_survey_answers.each do |answer|

                question = WkSurveyQuestion.find_by(id: answer.survey_question_id)

                questions << {
                    question: question&.name,
                    answer: answer.choice_text
                }

            end

            residents << {
                resident_name: resident_name,
                evaluation_name: survey.name,
                response_date: response.created_at.try(:to_date),
                questions: questions,
                # Full per-question detail (every choice + selected state) so the PDF
                # can render the same layout as the on-screen report.
                groups: build_response_groups(questions_by_group, response)
            }

        end

        {
            title: survey.name,
            residents: residents
        }
    end

    # Builds the per-question detail for one response, mirroring the on-screen
    # survey rendering: top-level questions only, numbered per group (or
    # sequentially when ungrouped), each choice carrying its selected state.
    # Returns: [{ name: <group or nil>, questions: [{ index:, name:, type:,
    #             header:, footer:, choices: [{name:, selected:}], text_value: }] }]
    def build_response_groups(questions_by_group, response)
        answered_choice_ids = response.wk_survey_answers.map(&:survey_choice_id).compact.to_set
        text_by_question = {}
        response.wk_survey_answers.each do |a|
            text_by_question[a.survey_question_id] = a.choice_text if a.choice_text.present?
        end

        groups = []
        group_counter = 0
        ungrouped_counter = 0

        questions_by_group.each do |group, questions|
            grouped = group.present? && group.name.present?
            group_counter += 1 if grouped
            question_counter = 0
            out_questions = []

            questions.select { |q| q.parent_id.nil? }.each do |q|
                if grouped
                    question_counter += 1
                    index = "#{group_counter}.#{question_counter}."
                else
                    ungrouped_counter += 1
                    index = "#{ungrouped_counter}."
                end

                item = {
                    index:  index,
                    name:   q.name,
                    type:   q.question_type,
                    header: q.header,
                    footer: q.footer
                }

                if ["RB", "CB"].include?(q.question_type)
                    item[:choices] = q.wk_survey_choices.map do |c|
                        { name: c.name, selected: answered_choice_ids.include?(c.id) }
                    end
                else
                    item[:text_value] = text_by_question[q.id].to_s
                end

                out_questions << item
            end

            groups << { name: (grouped ? group.name : nil), questions: out_questions }
        end

        groups
    end

    def getEvaluationResponses(evaluation_id)
        WkSurveyResponse
            .includes(:wk_survey_answers, :user)
            .where(survey_id: evaluation_id)
    end

	def getExportData(user_id, group_id, projId, from, to, location_id=nil, evaluation_id=nil)
		result = calcReportData(user_id, group_id, projId, from, to, location_id, evaluation_id)

		# customize: true tells the controller to use this module's own csv_export
		# (detailed, with evaluation name / resident / response date) instead of the
		# generic 3-column one. The same residents structure also feeds pdf_export.
		{
			title:     result[:title] || result[:error] || l(:report_evaluation),
			residents: result[:residents] || [],
			from:      from,
			to:        to,
			customize: true
		}
	end

	# Detailed CSV: title + date range header, then one fully-described row per
	# answered question (serial / evaluation / resident / response date / question /
	# answer), mirroring the layout used by the other resident reports.
	def csv_export(data)
		require 'csv'

		headers = [
			l(:label_si_no),
			l(:report_evaluation),
			l(:label_resident),
			l(:label_response_date),
			l(:label_evaluation_question),
			l(:label_evaluation_answer)
		]

		residents = data[:residents] || []

		CSV.generate do |csv|
			csv << [data[:title]]
			if data[:from].present? && data[:to].present?
				csv << ["#{data[:from]} #{l(:label_date_to)} #{data[:to]}"]
			end
			csv << []
			csv << headers

			if residents.all? { |r| (r[:questions] || []).blank? }
				csv << [l(:label_no_data)]
			else
				serial = 0
				residents.each do |res|
					(res[:questions] || []).each do |q|
						serial += 1
						csv << [
							serial,
							res[:evaluation_name],
							res[:resident_name],
							res[:response_date],
							q[:question],
							q[:answer]
						]
					end
				end
			end
		end
	end

	# Renders the evaluation report PDF so it mirrors the on-screen report
	# (_report_evaluation.html.erb): one block per resident response, each with a
	# centered survey-title heading, a Resident / Response Date header, and the
	# question/answer list. Residents are separated by page breaks, matching the
	# on-screen "page-break-after" between responses.
	#
	# Signature follows the sibling resident reports (report_occupancy_report,
	# report_move_in_move_out_by_date): named keywords for what's used + trailing
	# ** to absorb the rest (headers/data, only needed by csv_export).
	def pdf_export(residents: [], title: nil, location: nil, logo: nil, from: nil, to: nil, **)
		pdf = ITCPDF.new(current_language, "L")
		pdf.add_page

		# Margins/page width are only populated after the first page is added.
		page_width   = pdf.get_page_width
		left_margin  = pdf.get_original_margins['left']
		right_margin = pdf.get_original_margins['right']
		content_width = page_width - right_margin - left_margin

		# Standard report header (location / title / date range / logo) on the first
		# page, matching the other report PDFs so the "what report was generated"
		# context is clear.
		pdf.SetFontStyle('B', 13)
		pdf.RDMMultiCell(content_width, 5, location.to_s, 0, 'C') if location.present?
		pdf.RDMMultiCell(content_width, 5, (title.presence || l(:report_evaluation)), 0, 'C')
		if from.present? && to.present?
			pdf.RDMMultiCell(content_width, 5, "#{from} #{l(:label_date_to)} #{to}", 0, 'C')
		end
		if logo.present?
			pdf.Image(logo.diskfile.to_s, page_width - 50, 15, 30, 25)
		end
		pdf.ln(8)

		# Clean "No data" block when the filter yields nothing.
		if residents.blank?
			pdf.SetFontStyle('', 9)
			pdf.RDMCell(content_width, 8, l(:label_no_data), 1, 0, 'C', 0)
			pdf.ln
			return pdf.Output
		end

		half = content_width / 2

		residents.each_with_index do |res, idx|
			# One resident response per page, matching the on-screen page breaks.
			pdf.add_page if idx > 0

			# Survey-title heading (centered), like the <h2> in the on-screen block.
			pdf.SetFontStyle('B', 13)
			pdf.RDMMultiCell(content_width, 7, (res[:evaluation_name].presence || title.to_s), 0, 'C')
			pdf.ln(1)

			# Resident / Response Date header, shaded to read as a header box.
			pdf.set_fill_color(240, 242, 245)
			pdf.SetFontStyle('B', 9)
			pdf.RDMCell(half, 6, l(:label_resident), 0, 0, 'L', 1)
			pdf.RDMCell(half, 6, l(:label_response_date), 0, 0, 'L', 1)
			pdf.ln
			pdf.SetFontStyle('', 9)
			pdf.RDMCell(half, 6, res[:resident_name].to_s, 0, 0, 'L', 1)
			pdf.RDMCell(half, 6, res[:response_date].to_s, 0, 0, 'L', 1)
			pdf.ln(8)
			pdf.set_fill_color(255, 255, 255)

			groups = res[:groups] || []
			if groups.all? { |g| (g[:questions] || []).blank? }
				pdf.SetFontStyle('', 9)
				pdf.RDMCell(content_width, 7, l(:label_no_data), 1, 0, 'C', 0)
				pdf.ln
				next
			end

			# Render each group's questions, mirroring the on-screen survey: a
			# numbered question followed by every choice with a filled/empty marker
			# (radio: circle, checkbox: square) showing what was selected, or the
			# entered text for free-text questions.
			groups.each do |grp|
				if grp[:name].present?
					pdf.SetFontStyle('B', 11)
					pdf.set_fill_color(230, 230, 230)
					pdf.RDMCell(content_width, 7, " #{grp[:name]}", 0, 0, 'L', 1)
					pdf.ln(2)
					pdf.set_fill_color(255, 255, 255)
				end

				(grp[:questions] || []).each do |q|
					render_question(pdf, q, content_width, left_margin)
				end
			end
		end

		pdf.Output
	end

	# Markers for choice state. These live in the Geometric Shapes Unicode block,
	CHOICE_LINE_HEIGHT = 6 # mm, per choice line

	# Renders one question block (header / numbered question / choices or text /
	# footer) into the PDF, indenting choices like the on-screen layout.
	def render_question(pdf, q, content_width, left_margin)
		choice_x     = left_margin + 6           # marker column
		text_x       = choice_x + 6              # choice text column (after marker)
		text_width   = content_width - (text_x - left_margin)

		# Optional question header (shown as italic note above the question).
		if q[:header].present?
			pdf.SetFontStyle('I', 8)
			pdf.set_x(left_margin)
			pdf.RDMMultiCell(content_width, 5, q[:header].to_s, 0, 'L')
		end

		# Numbered question text.
		pdf.SetFontStyle('B', 10)
		pdf.set_x(left_margin)
		pdf.RDMMultiCell(content_width, 6, "#{q[:index]} #{q[:name]}", 0, 'L')

		if ["RB", "CB"].include?(q[:type])
			pdf.SetFontStyle('', 10)
			(q[:choices] || []).each do |c|
				y0 = pdf.get_y
				# Draw the radio/checkbox marker as a vector shape so it never depends
				# on font glyph coverage (freesans lacks the filled-circle glyph).
				draw_choice_marker(pdf, q[:type], choice_x, y0, c[:selected])
				# Choice label, offset past the marker; advances Y (handles wrapping).
				pdf.set_xy(text_x, y0)
				pdf.RDMMultiCell(text_width, CHOICE_LINE_HEIGHT, c[:name].to_s, 0, 'L')
			end
		else
			pdf.SetFontStyle('', 10)
			pdf.set_x(choice_x)
			pdf.RDMMultiCell(content_width - 6, 6, q[:text_value].to_s, 0, 'L')
		end

		# Optional question footer.
		if q[:footer].present?
			pdf.SetFontStyle('I', 8)
			pdf.set_x(left_margin)
			pdf.RDMMultiCell(content_width, 5, q[:footer].to_s, 0, 'L')
		end

		# Separator line between questions, matching the on-screen divider.
		pdf.ln(1)
		line_y = pdf.get_y
		pdf.set_draw_color(180, 180, 180)
		pdf.Line(left_margin, line_y, left_margin + content_width, line_y)
		pdf.set_draw_color(0, 0, 0)
		pdf.ln(2)
	end

	# Draws a radio (circle) or checkbox (square) marker as a vector shape, filled
	# in when selected. Vector drawing is used instead of Unicode glyphs because the
	# PDF font (freesans) does not include the filled-circle/▣ glyphs.
	def draw_choice_marker(pdf, type, x, y, selected)
		size = 3.2                       # marker box size (mm)
		cy   = y + (CHOICE_LINE_HEIGHT - size) / 2.0 + size / 2.0
		mx   = x + 0.5                   # small left padding

		pdf.set_line_width(0.25)
		pdf.set_draw_color(80, 80, 80)
		pdf.set_fill_color(60, 60, 60)

		if type == "CB"
			# Square box; selected → filled inner square (reads as "checked").
			top = cy - size / 2.0
			pdf.Rect(mx, top, size, size, 'D')
			if selected
				inset = size * 0.28
				pdf.Rect(mx + inset, top + inset, size - 2 * inset, size - 2 * inset, 'F')
			end
		else
			# Radio circle; selected → filled inner dot.
			r = size / 2.0
			ccx = mx + r
			pdf.Circle(ccx, cy, r, 0, 360, 'D')
			pdf.Circle(ccx, cy, r * 0.5, 0, 360, 'F') if selected
		end

		# Restore defaults for following content.
		pdf.set_draw_color(0, 0, 0)
		pdf.set_fill_color(255, 255, 255)
		pdf.set_line_width(0.2)
	end
end