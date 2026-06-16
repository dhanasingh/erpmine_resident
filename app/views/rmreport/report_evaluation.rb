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

        # collect all responses
        survey.wk_survey_responses.each do |response|

            resident_name = ""

            residentObj = RmResident.left_join_contacts
                .where("rm_residents.id = ?", response.survey_for_id)
                .select("wk_accounts.name as account_name, first_name, last_name, resident_type")
                .first

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
                questions: questions
            }

        end

        {
            title: survey.name,
            residents: residents
        }
    end

    def getEvaluationResponses(evaluation_id)
        WkSurveyResponse
            .includes(:wk_survey_answers, :user)
            .where(survey_id: evaluation_id)
    end

	def getExportData(user_id, group_id, projId, from, to, location_id=nil, evaluation_id=nil)
		calcReportData(user_id, group_id, projId, from, to, location_id, evaluation_id)
	end

	def pdf_export(data:, headers:, title: nil, **args)
		pdf = ITCPDF.new(current_language, "L")
		pdf.AddPage

		pdf.SetFontStyle('B', 14)
		pdf.RDMMultiCell(200, 10, title.to_s, 0)

		pdf.ln(5)

		width = 65

		pdf.SetFontStyle('B', 10)

		headers.each do |key, value|
			pdf.RDMCell(width, 10, value.to_s, 1, 0, 'C')
		end

		pdf.ln

		pdf.SetFontStyle('', 9)

		data.each do |row|
			headers.each do |key, value|
				pdf.RDMCell(width, 10, row[key].to_s, 1, 0)
			end
			pdf.ln
		end

		pdf.Output
	end
end