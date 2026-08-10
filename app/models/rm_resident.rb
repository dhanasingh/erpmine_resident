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
  belongs_to :bed, foreign_key: "bed_id", class_name: "WkInventoryItem"
  belongs_to :apartment, foreign_key: "apartment_id", class_name: "WkInventoryItem"
  belongs_to :wk_crm_contact, -> { where(rm_residents: {resident_type: 'WkCrmContact'}) }, foreign_key: 'resident_id'
  scope :current_move_out_resident,  -> { where(:move_out_date => nil) }
  has_many :resident_services, foreign_key: "rm_resident_id", :class_name => 'RmResidentService', :dependent => :restrict_with_error
  has_many :incidents, foreign_key: "rm_resident_id", :class_name => 'RmIncident', :dependent => :restrict_with_error
  has_many :care_billing_assignments, foreign_key: "rm_resident_id", :class_name => 'RmCareBillingAssignment', :dependent => :destroy
  validates_presence_of :apartment_id, :resident_id

	# Ensure resident.resident (contact Object) returns nil unless resident.resident_type == "WkCrmContact"
	def resident
		return unless(resident_type != "WkCrmContact" || resident_type != "WkAccount")
		super
	end

  scope :left_join_contacts, lambda {
    joins("LEFT OUTER JOIN #{WkCrmContact.table_name} ON #{WkCrmContact.table_name}.id = #{RmResident.table_name}.resident_id and resident_type = 'WkCrmContact' " + get_comp_con(WkCrmContact.table_name))
    .joins("LEFT OUTER JOIN #{WkAccount.table_name} ON #{WkAccount.table_name}.id = #{RmResident.table_name}.resident_id and resident_type = 'WkAccount' " + get_comp_con(WkAccount.table_name))
  }

  scope :left_join_inventory, lambda {
    joins("LEFT OUTER JOIN #{WkInventoryItem.table_name} ON #{WkInventoryItem.table_name}.id = #{RmResident.table_name}.resident_id" + get_comp_con(WkInventoryItem.table_name))
  }

  # Scope `relation` to residents whose physical apartment — directly via apartment_id
  # or via their bed's parent apartment — is in the allowed apartment-location scope
  # (picked-zone subtree ∩ the current user's accessible locations). Used by the
  # occupancy/move-in dashboard graphs. nil scope => unrestricted => relation unchanged.
  def self.in_apartment_location_scope(relation = all, location_id = nil)
    loc_ids = WkLocation.report_location_ids(location_id)
    return relation if loc_ids.nil?
    apt_ids = WkInventoryItem.where(location_id: (loc_ids.presence || [-1])).pluck(:id).presence || [-1]
    relation.where(
      "#{table_name}.apartment_id IN (:apt) OR #{table_name}.bed_id IN " \
      "(SELECT b.id FROM #{WkInventoryItem.table_name} b WHERE b.parent_id IN (:apt))",
      apt: apt_ids
    )
  end

  # Resident ids within the allowed contact/account-location scope (picked-zone
  # subtree ∩ the current user's accessible locations) — the same dimension as the
  # resident list and evaluation report. Returns nil when unrestricted (admin and no
  # location picked) so callers can skip filtering entirely.
  def self.ids_in_location_scope(location_id = nil)
    loc_ids = WkLocation.report_location_ids(location_id)
    return nil if loc_ids.nil?
    WkLocation.filter_by_contact_account_location(left_join_contacts, loc_ids)
              .pluck("#{table_name}.id")
  end

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