actions :create, :create_if_missing, :delete, :nothing, :touch
default_action :create

attribute :path, :kind_of => String, :name_attribute => true
attribute :source, :kind_of => String, :required => true
attribute :variables, :kind_of => Hash
attribute :section_name, :kind_of => String, :required => true
attribute :surround_with_config_root, :kind_of => [TrueClass, FalseClass], :default => false
