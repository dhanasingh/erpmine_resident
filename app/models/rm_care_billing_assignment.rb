class RmCareBillingAssignment < ApplicationRecord
  belongs_to :rm_resident,     class_name: 'RmResident'
  belongs_to :survey_response, class_name: 'WkSurveyResponse', foreign_key: 'survey_response_id'

  validates_presence_of :rm_resident_id, :survey_response_id, :effective_date
  validates_uniqueness_of :survey_response_id, scope: :rm_resident_id
end
