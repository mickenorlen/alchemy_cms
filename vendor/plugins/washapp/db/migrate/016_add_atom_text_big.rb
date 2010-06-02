class AddAtomTextBig < ActiveRecord::Migration
  def self.up
    create_table :wa_atom_text_bigs do |t|
          #render_content in model
          #render_editor in model      
          t.column :content,  :string
    end
  end

  def self.down
        drop_table :wa_atom_text_bigs
  end
end
