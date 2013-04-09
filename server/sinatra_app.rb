require 'rubygems'
require 'data_mapper'
require 'sinatra'
require 'json'
require 'haml'
require 'regex'
require 'sinatra/logger'

#add the directory of this file to Ruby's load paths array
$LOAD_PATH.unshift('.')

enable :logging

configure :production do 
  api = JSON.parse(ENV['VCAP_SERVICES'])
  pgrKey = api.keys.select{ |s| s =~ /postgres/i }.first
  pgr = api[pgrKey].first['credentials']
  uri = "postgres://#{pgr['username']}:#{pgr['password']}@#{pgr['host']}:#{pgr['port']}/#{pgr['name']}"
  DataMapper::Logger.new($stdout, :debug)
  DataMapper.setup(:default, uri)   
end

configure :test do 
  uri = "postgres://#{Dir.pwd}/test.db}"
  DataMapper::Logger.new($stdout, :debug)
  DataMapper.setup(:default, uri)#'sqlite::memory:')   
end


#
# people
#

#get people
get '/api/people' do
  content_type :json
  { :people => Person.all }.to_json()
end

post 'api/households/mls-csv' do
  csv_households = request.body.read
end

post 'api/households/directory-csv' do
  csv_households = request.body.read
  csv = CSV.parse(csv_households, :headers => true)
		csv.each do |row|
				row = row.to_hash.with_indifferent_access
				Moulding.create!(row.to_hash.symbolize_keys)
		end
  
end


#create a person
post '/api/people' do
  content_type :json
  
  request.body.rewind
  post = JSON.parse request.body.read
  p = Person.create({
        :name     => FullName.create(post['name']),
        :address  => PersonalAddress.create(post['address']),
        :phones   => post['phones'].map { |num| Phone.create(num) },
        :emails   => post['emails'].map { |addr| Email.create(addr) },
        :notes    => (post['notes'] || []).map { |note| PersonNote.create(note) },
        :gender   => post['gender'],
        :ward     => post['ward'],
        :dob      => post['dob'],
        :family_role     => post['family_role'],
        :household => Household.get(post['household_id'])
      })   
       
  #h.people << p
  #h.save    
  p.save
  p.to_json( :exclude => { :household => [:people]}, :methods => [ :household ])
end



#
# households
#

get '/api/hometeachers' do
  content_type :json
  { :teachers => Person.hometeachers }.to_json
end

get '/api/households' do
  content_type :json
  { :households => Household.all }.to_json()
end

post '/api/households' do
  content_type :json

  request.body.rewind
  post = JSON.parse request.body.read  
  
  h = Household.create({
    :name    => post['name'],
    :phone   => post['phone'],
    :ward    => post['ward'],
    :address => HomeAddress.create(post['address']),
    :notes   => post['notes'].map { |note| HouseholdNote.create(note) }
  })
  
  h.to_json
end

#
# assignments
#


post '/api/snapshots/:id/assigments' do
  content_type :json
  
  request.body.rewind
  post = JSON.parse request.body.read  

  if snapshot = Snapshot.get(params[:id])
    snapshot.assignments.create({
							:households => Household.all(:id => post['households']),
							:teachers   => Person.all(:id => post['teachers']),
							:district   => post['district'],
							:notes      => post['notes'].map { |note| AssignmentNote.create(note) }
				})
    return snapshot.to_json
  end
end

delete '/api/assignments/:id' do
  content_type :json
  
  request.body.rewind
  post = JSON.parse request.body.read  

  assignment = Assignment.get(params[:id])
  
  unless assignment.nil? 
    #assignment.group.assignments.delete_if { |assign| assign.id == assignment.id }
    #assignment.group.assignments.save
    if assignment.destroy
      return { :assignment => assignment, :status => :deleted }.to_json
    else
      return { :assignment => assignment, :status => :not_deleted }.to_json
    end
  end
end

put '/api/assignments/:id' do
  content_type :json 

  request.body.rewind
  post = JSON.parse request.body.read 

  puts "updating assignment"

  assignment = Assignment.get(params[:id])

  unless assignment.nil?

    new_teacher_ids = post['teachers'] - assignment.teachers.map { |teacher| teacher.id }
    new_teachers    = Person.all(:id => new_teacher_ids) 
    assignment.teachers.keep_if { |teacher| post['teachers'].include? teacher.id }
    assignment.teachers.save
    assignment.teachers.concat new_teachers
    assignment.teachers.save  
      
    new_house_ids = post['households'] - assignment.households.map { |house| house.id }  
    new_houses    = Household.all(:id => new_house_ids)
    assignment.households.keep_if { |house| post['households'].include? house.id }
    assignment.households.save
    assignment.households.concat new_houses
    assignment.households.save
    
    return assignment.to_json
  end
  
  { :error => "failed to find assignment" }.to_json
end


post '/api/snapshots' do
  content_type :json
  
  request.body.rewind
  post = JSON.parse request.body.read  

  ht_snapshot = Snapshot.create({
    :yr          => post['yr'],
    :mo          => post['mo'],
    :tag         => post['tag'],
    :state       => post['state']
  })
  
  post['assignments'].each { |assignment|
					ht_snapshot.assignments.create({
							:households => Household.all(:id => assignment['households']),
							:teachers   => Person.all(:id => assignment['teachers']),
							:district   => assignment['district'],
							:notes      => assignment['notes']#.map { |note| AssignmentNote.create(note) }
				})
		}

  ht_snapshot.to_json
end

get '/api/assignments/:yr/:mo' do
  content_type :json
  { :assignments => Assignment.all({ :yr => params[:yr], :mo => params[:mo] }) }.to_json
end

get '/api/tagged-assignments/:tag' do
  content_type :json
  { :assignments => Assignment.all(:tag => params[:tag]) }.to_json
end


class Snapshot
  include DataMapper::Resource
  property :id, DataMapper::Property::Serial
  property :yr,  Integer
  property :mo,  Integer
  property :tag, String
  
  has n, :assignments
  
  property :state, Enum[ :sandbox, :active ], :default => :sandbox
  property :created_at, DateTime
  property :updated_at, DateTime 
  
  # this method is called on a single instance
  def to_json(options={})
    options[:methods] ||= []
    [ :assignments ].each{ |method| options[:methods] << method } 
    super(options)
  end

  # this method is called for each instance in an Array to avoid circular references.
  def as_json(options={})
    options[:methods] ||= []
    [ :assignments ].each{ |method| options[:methods] << method } 
    super(options)
  end
end


class Visit
  include DataMapper::Resource
  property   :yr,  Integer, :key => true
  property   :mo,  Integer, :key => true
  
  belongs_to :household, :key => true
  belongs_to :teacher, :model => 'Person', :key => true 
  
  has n, :notes, :model => 'VisitNote', :constraint => :destroy
  
  property :visited, Boolean, :allow_nil => true
  
  property :created_at, DateTime
  property :updated_at, DateTime
end



class Phone
  include DataMapper::Resource
  property :id, DataMapper::Property::Serial

  belongs_to :person

  property :number, String
  
  property :created_at, DateTime
  property :updated_at, DateTime 
end

class Email
  include DataMapper::Resource
  belongs_to :person
  
  property :id, DataMapper::Property::Serial
  property :address, String
end


class HomeAddress
  include DataMapper::Resource
  property :id, DataMapper::Property::Serial
  property :street, String
  property :city,   String
  property :state,  String
  property :zip,    String
  
  property :created_at, DateTime
  property :updated_at, DateTime
  
  belongs_to :household, :required => false
end

class PersonalAddress
  include DataMapper::Resource
  property :id, DataMapper::Property::Serial
  property :street, String
  property :city,   String
  property :state,  String
  property :zip,    String
  
  property :created_at, DateTime
  property :updated_at, DateTime
  
  belongs_to :person, :required => false
end

class FullName
  include DataMapper::Resource
  property :id, DataMapper::Property::Serial
  property :first,  String
  property :last,   String
  property :middle, String
  
  property :created_at, DateTime
  property :updated_at, DateTime
  
  belongs_to :person, :required => false
end

class District
  include DataMapper::Resource

  property :id, DataMapper::Property::Serial
  property :number, Integer
  property :reports_to, String #should be district leader login
  property :created_at, DateTime
  property :updated_at, DateTime
end

#TODO use dm-is-remixable to make it D.R.Y.
class Note
end  

class PersonNote < Note
  include DataMapper::Resource
  property :id, DataMapper::Property::Serial
  property :text, String   
  property :created_at, DateTime
  property :updated_at, DateTime
  belongs_to :person, :required => false
end

class HouseholdNote < Note
  include DataMapper::Resource
  property :id, DataMapper::Property::Serial
  property :text, String   
  property :created_at, DateTime
  property :updated_at, DateTime
  belongs_to :household, :required => false
end

class AssignmentNote < Note
  include DataMapper::Resource
  property :id, DataMapper::Property::Serial
  property :text, String   
  property :created_at, DateTime
  property :updated_at, DateTime
  belongs_to :assignment, :required => false
end

class VisitNote < Note
  include DataMapper::Resource
  property :id, DataMapper::Property::Serial
  property :text, String   
  property :created_at, DateTime
  property :updated_at, DateTime
  belongs_to :visit, :required => false
end



class Assignment
  include DataMapper::Resource

  property :id, DataMapper::Property::Serial
  
  belongs_to :snapshot

  property :district,  Integer
  property :state, Enum[ :planned, :assigned ], :default => :planned  

  has n, :teachers, 'Person', :through => Resource
  has n, :households, :through => Resource
  
  has n, :notes, 'AssignmentNote'

  property :created_at, DateTime
  property :updated_at, DateTime
  
  # this method is called on a single instance
  def to_json(options={})
    options[:methods] ||= []
    [ :notes, :teachers, :households ].each{ |method| options[:methods] << method } 
    super(options)
  end

  # this method is called for each instance in an Array to avoid circular references.
  def as_json(options={})
    options[:methods] ||= []
    [ :notes, :teachers, :households ].each{ |method| options[:methods] << method } 
    super(options)
  end
end

class Person
  include DataMapper::Resource
  
  property :id, DataMapper::Property::Serial
  
  belongs_to :household
  
  has 1, :name, :model => 'FullName'
  has 1, :address, :model => 'PersonalAddress'
  
  property :gender, Enum[:f, :m] 
  property :dob, Date
  property :family_role, Enum[:head, :spouse, :child, :grandparent, :other]
  
  has n, :phones, :constraint => :destroy
  has n, :emails, :constraint => :destroy
  has n, :notes, :model => 'PersonNote'

  property :ward, String # could be living outside of ward  
  property :elder, Boolean, :default => false
  
  # Hometeacher
  property :assignable, Boolean, :default => true

  has n,   :assignments, :through => Resource
  
  has n,   :visits, :child_key => [:teacher_id]

  property :created_at, DateTime
  property :updated_at, DateTime 
  
  def self.hometeachers
    Person.all({ :assignable => true, :gender => :m }).delete_if { |person| person.age < 11 }
  end
  
  # this method is called on a single instance
  def to_json(options={})
    options[:methods] ||= []
    [ :name, :phones, :emails, :notes, :address ].each{ |method| options[:methods] << method } 
    super(options)
  end

  # this method is called for each instance in an Array to avoid circular references.
  def as_json(options={})
    options[:methods] ||= []
    [ :name, :phones, :emails, :notes, :address ].each{ |method| options[:methods] << method } 
    super(options)
  end
  
  def eligible_to_ht? 
    gender == :m && age > 11
  end
  
  def assignable_to_ht?
    eligible_to_ht? && assignable
  end
  
  def ht?
    assignments.size > 0 
  end
  
  def age
    now = Date.today
    now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
  end
  
end

class Household
  include DataMapper::Resource
  property :id, DataMapper::Property::Serial
  property :name,   String, :required => true
  property :phone,  String
  property :ward,   String #if they moved
  has 1,  :address, :model => 'HomeAddress'
    
  has n, :people, :model => 'Person', :child_key=>[:household_id]
  
  has n, :notes, :model => 'HouseholdNote'
  
  has n, :visits, :child_key=>[:household_id]

  has n, :assignments, :through => Resource

  property :created_at, DateTime
  property :updated_at, DateTime 
  
  # this method is called on a single instance
  def to_json(options={})
    options[:methods] ||= []
    [ :people, :visits, :notes, :address ].each{ |method| options[:methods] << method } 
    super(options)
  end

  # this method is called for each instance in an Array to avoid circular references.
  def as_json(options={})
    options[:methods] ||= []
    [ :people, :visits, :notes, :address ].each{ |method| options[:methods] << method } 
    super(options)
  end
end

DataMapper.finalize.auto_upgrade!


