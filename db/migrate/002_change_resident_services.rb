class ChangeResidentServices < ActiveRecord::Migration[5.2]

	def change
		reversible do |dir|
			dir.up do
				add_reference :rm_resident_services, :rm_resident, :class => "rm_residents"
				RmResidentService.all.each do |service|
					resID = RmResident.where("resident_id = ? and resident_type = ? ", service.resident_id, service.resident_type).order("move_in_date desc").first.id
					service.rm_resident_id = resID
					service.save
				end
				remove_reference :rm_resident_services, :resident, polymorphic: true
			end
			dir.down do
				add_reference :rm_resident_services, :resident, polymorphic: true, index: true
				RmResidentService.all.each do |service|
					resObj = RmResident.find(service.rm_resident_id.to_i)
					service.resident_id = resObj.resident_id
					service.resident_type = resObj.resident_type
					service.save
				end
				remove_reference :rm_resident_services, :rm_resident, :class => "rm_residents"
			end
		end
	end
end