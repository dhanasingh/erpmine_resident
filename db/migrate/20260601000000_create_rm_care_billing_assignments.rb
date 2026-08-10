class CreateRmCareBillingAssignments < ActiveRecord::Migration[5.2]
  def change
    create_table :rm_care_billing_assignments do |t|
      t.references :rm_resident,       null: false, index: true
      t.references :survey_response,   null: false, index: true
      t.date        :effective_date,   null: false
      t.references :created_by_user,   class_name: 'User'
      t.references :updated_by_user,   class_name: 'User'
      t.timestamps null: false
    end

    add_index :rm_care_billing_assignments,
              [:rm_resident_id, :survey_response_id],
              unique: true,
              name: 'idx_rm_care_billing_unique'

  end
end
