class CreateWkResidentManagement  < ActiveRecord::Migration[4.2]

	def change
		create_table :rm_resident_services do |t|
			t.references :resident, polymorphic: true, index: true
			t.references :issue, :null => false
			t.date :start_date
			t.date :end_date
			t.string :frequency, :null => false, :limit => 2, :default => 'M'
			# t.string :requirement_type, :null => false, :limit => 2, :default => 'S'
			t.integer :no_of_occurrence, :default => 0		
			t.references :created_by_user, :class => "User"
			t.references :updated_by_user, :class => "User"
			t.timestamps null: false
		end
		
		create_table :rm_residents do |t|
			t.references :resident, polymorphic: true, index: true
			t.datetime :move_in_date
			t.datetime :move_out_date
			t.references :apartment, :class => "wk_inventory_items", :index => true
			t.references :bed, :class => "wk_inventory_items", :index => true
			t.references :move_out_reason, :class => "wk_crm_enumerations", :index => true
			t.references :created_by_user, :class => "User"
			t.references :updated_by_user, :class => "User"
			t.timestamps null: false
		end
	end
end