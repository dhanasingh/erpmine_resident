class RmResident < ActiveRecord::Base
  belongs_to :resident, :polymorphic => true
  has_one :location,  :through => :resident
  scope :current_resident,  -> { where(:move_out_date => nil) }
  belongs_to :bed, foreign_key: "bed_id", class_name: "WkInventoryItem"
  belongs_to :apartment, foreign_key: "apartment_id", class_name: "WkInventoryItem"
  belongs_to :wk_crm_contact, -> { where(rm_residents: {resident_type: 'WkCrmContact'}) }, foreign_key: 'resident_id'
   # Ensure review.shop returns nil unless review.reviewable_type == "Shop"
   def contact
     return unless reviewable_type == "WkCrmContact"
     super
   end
  
  scope :left_join_contacts, lambda {
    joins("LEFT OUTER JOIN #{WkCrmContact.table_name} ON #{WkCrmContact.table_name}.id = #{RmResident.table_name}.resident_id and resident_type = 'WkCrmContact' ")
  }
  
  scope :left_join_inventory, lambda {
    joins("LEFT OUTER JOIN #{WkInventoryItem.table_name} ON #{WkInventoryItem.table_name}.id = #{RmResident.table_name}.resident_id")
  }
  
end