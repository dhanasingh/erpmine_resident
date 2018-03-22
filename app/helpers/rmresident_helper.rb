module RmresidentHelper
include RmapartmentHelper
include WkassetHelper

	WkCrmContact.class_eval do
		has_many :resident_services, as: :resident, :dependent => :restrict_with_error, :class_name => 'RmResidentService'
		has_many :residents, as: :resident, :dependent => :restrict_with_error, :class_name => 'RmResident'
		#has_one :current_resident, as: :resident, :dependent => :restrict_with_error, :class_name => 'RmResident'
		#scope :current_resident, joins(:residents).merge(RmResident.current_resident)
		#scope :status, lambda {|arg| where(arg.blank? ? nil : {:status => arg.to_i}) }
	end

	def residentArray(needBlank)
		resdientArr = Array.new
		residentObj = RmResident.order(:id) 
		residentObj.each do | resident |
			resdientArr << [resident.resident.name, resident.resident.id]
		end
		resdientArr.unshift(["",""]) if needBlank
		resdientArr
	end	
	
	def moveInOutHash
		moveHash = {
			'MI' => l(:button_move_in),
			'MO' => l(:label_move_out)		
		}
		moveHash
	end
end
