class RmResidentService < ActiveRecord::Base
  include Redmine::SafeAttributes
  attr_protected :others
  belongs_to :resident, :polymorphic => true
  belongs_to :issue
  belongs_to :created_user, :class_name => 'User', :foreign_key => 'created_by_user_id'
  belongs_to :updated_user, :class_name => 'User', :foreign_key => 'updated_by_user_id'
  
  safe_attributes 	'resident_id', 'resident_type','issue_id', 'start_date', 'end_date', 'frequency', 'no_of_occurrence', 'created_by_user_id', 'updated_by_user_id'
  
end