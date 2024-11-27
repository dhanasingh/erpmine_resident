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

class RmResident < ApplicationRecord
  belongs_to :resident, :polymorphic => true
  has_one :location,  :through => :resident
  scope :current_resident,  -> { where("move_out_date IS NULL OR move_out_date > ? ", Date.today).order("move_in_date DESC") }
  belongs_to :bed, foreign_key: "bed_id", class_name: "WkInventoryItem"
  belongs_to :apartment, foreign_key: "apartment_id", class_name: "WkInventoryItem"
  belongs_to :wk_crm_contact, -> { where(rm_residents: {resident_type: 'WkCrmContact'}) }, foreign_key: 'resident_id'
  scope :current_move_out_resident,  -> { where(:move_out_date => nil) }
  has_many :resident_services, foreign_key: "rm_resident_id", :class_name => 'RmResidentService', :dependent => :restrict_with_error
  validates_presence_of :apartment_id, :resident_id

	# Ensure resident.resident (contact Object) returns nil unless resident.resident_type == "WkCrmContact"
	def resident
		return unless(resident_type != "WkCrmContact" || resident_type != "WkAccount")
		super
	end

  scope :left_join_contacts, lambda {
    joins("LEFT OUTER JOIN #{WkCrmContact.table_name} ON #{WkCrmContact.table_name}.id = #{RmResident.table_name}.resident_id and resident_type = 'WkCrmContact' ")
    .joins("LEFT OUTER JOIN #{WkAccount.table_name} ON #{WkAccount.table_name}.id = #{RmResident.table_name}.resident_id and resident_type = 'WkAccount' ")
  }

  scope :left_join_inventory, lambda {
    joins("LEFT OUTER JOIN #{WkInventoryItem.table_name} ON #{WkInventoryItem.table_name}.id = #{RmResident.table_name}.resident_id")
  }

  def type
    if self.resident_type == "WkAccount"
      self.resident.account_type
    else
      self.resident.contact_type
    end
  end

  def name
    if self.resident_type == "WkAccount"
      self.resident.name
    else
      (self.resident&.first_name || '') + "  " + self.resident&.last_name
    end
  end

  def getCurrentResidentStatus
    RmResident.where("resident_type = ? and resident_id = ? and move_out_date is null", self.resident_type, self.resident_id)
  end

end