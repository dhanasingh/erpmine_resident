class CreateRmIncidents < ActiveRecord::Migration[4.2]
	DEFAULT_INCIDENT_TYPES = ['Fall', 'Medication', 'Behavioral', 'Abuse', 'Property Damage', 'Other'].freeze
	INCIDENT_ENUM_TYPE = 'RIT'.freeze

	def up
		create_table :rm_incidents do |t|
			t.references :rm_resident, null: false, index: true
			t.datetime :incident_datetime, null: false
			t.references :incident_type, index: true
			t.string :location, limit: 255
			t.text :desc
			t.text :witnesses
			t.text :imm_action
			t.text :prev_action
			t.text :injuries
			t.text :notes
			t.text :follow_up
			t.references :rpt_user, index: true, class: "User"
			t.references :created_by_user, class: "User"
			t.references :updated_by_user, class: "User"
			t.timestamps null: false
		end

		DEFAULT_INCIDENT_TYPES.each_with_index do |value, index|
			enum_entry = WkCrmEnumeration.where(enum_type: INCIDENT_ENUM_TYPE, name: value).first_or_initialize
			enum_entry.position = (index + 1).to_s if enum_entry.position.blank?
			enum_entry.active = true if enum_entry.active.nil?
			enum_entry.is_default = (index == 0) if enum_entry.is_default.nil?
			enum_entry.save!
		end

	end

	def down
		drop_table :rm_incidents

		WkCrmEnumeration.where(enum_type: INCIDENT_ENUM_TYPE, name: DEFAULT_INCIDENT_TYPES).delete_all
	end
end
