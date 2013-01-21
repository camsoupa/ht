require 'mongo_mapper'

class Address
  include MongoMapper::EmbeddedDocument
  key :street, String
  key :city, String
  key :state, String
  key :zip, String
end

class Household
  include MongoMapper::Document
  key  :head_id, ObjectId
  key  :name, String
  key  :address, String
  key  :home_phone, String
  key  :member_ids, Array, :index => true
  many :members, :in => :member_ids
  key  :hometeachers_id, ObjectId
  many :notes
  key  :moved_out, Boolean
  timestamps!
end

class Member
  include MongoMapper::Document
  key :first_name, String
  key :last_name, String
  key :address, String
  key :phones, Array
  key :emails, Array
  key :birthdate, Date
  many :notes
  timestamps!
end

class Note
  include MongoMapper::EmbeddedDocument
  key :text
  timestamps!
end  

class HTAssignment
  include MongoMapper::Document
  key  :companion_ids, Array, :index => true
  many :companions, :in => :companion_ids
  key  :district_id, ObjectId
  key  :begin_time, Date
  key  :end_time, Date, :default => nil
  timestamps!
end

class District
  key :leader_id, ObjectId
  key :number, Integer
end






