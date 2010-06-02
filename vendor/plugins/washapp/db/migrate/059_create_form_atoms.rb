class CreateFormAtoms < ActiveRecord::Migration

  def self.up
    create_table :wa_atom_selectboxes do |t|
      t.boolean :validate, :default => false
      t.string :name
      t.boolean :multiple, :default => false
      t.text :options
      t.timestamps
    end
    create_table :wa_atom_checkboxes do |t|
      t.boolean :validate, :default => false
      t.string :name
      t.boolean :checked, :default => false
      t.timestamps
    end
    create_table :wa_atom_textareas do |t|
      t.boolean :validate, :default => false
      t.string :name
      t.timestamps
    end
    create_table :wa_atom_textfields do |t|
      t.boolean :validate, :default => false
      t.string :name
      t.boolean :hidden, :default => false
      t.timestamps
    end
    create_table :wa_atom_submitbuttons do |t|
      t.string :label
      t.boolean :close_form, :default => true
      t.timestamps
    end
    create_table :wa_atom_resetbuttons do |t|
      t.string :label
      t.boolean :close_form, :default => false
      t.timestamps
    end
    create_table :wa_atom_formtags do |t|
      t.string :action
      t.timestamps
    end
  end

  def self.down
    drop_table :wa_atom_selectboxes
    drop_table :wa_atom_textareas
    drop_table :wa_atom_textfields
    drop_table :wa_atom_submitbuttons
    drop_table :wa_atom_resetbuttons
    drop_table :wa_atom_checkboxes
    drop_table :wa_atom_formtags
  end

end
