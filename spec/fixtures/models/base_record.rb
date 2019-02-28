require 'active_record'

class BaseRecord < ActiveRecord::Base
  self.abstract_class = true
  establish_connection(adapter: 'sqlite3', database: 'spec/db/sqlite3.db')
end
