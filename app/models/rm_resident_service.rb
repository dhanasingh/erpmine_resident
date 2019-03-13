class RmResidentService < ActiveRecord::Base
  include Redmine::SafeAttributes
  # attr_protected :others
  belongs_to :resident, :polymorphic => true
  belongs_to :issue
  belongs_to :created_user, :class_name => 'User', :foreign_key => 'created_by_user_id'
  belongs_to :updated_user, :class_name => 'User', :foreign_key => 'updated_by_user_id'
  validates_presence_of :start_date, :issue_id,  :resident_id
  safe_attributes 	'resident_id', 'resident_type','issue_id', 'start_date', 'end_date', 'frequency', 'no_of_occurrence', 'created_by_user_id', 'updated_by_user_id'
  
  validate :end_date_is_after_start_date
  
   def end_date_is_after_start_date
		if !end_date.blank?
			if end_date < start_date 
				errors.add(:end_date, "cannot be before the start date") 
			end 
		end
		
		currentRes = self.resident.residents.current_resident
		if currentRes[0].blank?
			errors.add("Could not add Service and Amenities for Former residents") 
		else
			if !end_date.blank? && !currentRes[0].move_out_date.blank? && currentRes[0].move_out_date.to_date < end_date 
				errors.add(:end_date, "cannot be after the move out date") 
			end 
			if currentRes[0].move_in_date.to_date > start_date 
				errors.add(:start_date, "cannot be before the move in date") 
			end 
		end 
	end
end