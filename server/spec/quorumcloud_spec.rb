ENV['RACK_ENV'] = 'test'

require '../sinatra_app'
require 'rspec'
require 'rack/test'
require 'json'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  conf.before(:all) { DataMapper.finalize.auto_migrate! }
end

describe 'Quorum Cloud' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end
  
  it "accepts new households" do
    (1..4).each{ |num|
      house_json = IO.read("household#{num}.json")
				  house_hash = JSON.parse house_json
				  
				  post '/api/households', house_json
				  
				  last_response.should be_ok
				  
				  actual = JSON.parse(last_response.body)
				  expected = house_hash
				  
				  actual.should have_key('created_at')
				  actual.should have_key('updated_at')
				  expected.keys.each { |k| actual.should have_key(k) }
				  actual.values.each { |v| v.should_not eq(nil) }
    }
  end
  
  it "accepts new people" do
    (1..4).each{ |num|
				  person_json = IO.read("person#{num}.json")
				  person_hash = JSON.parse person_json
				  
				  post '/api/people', person_json
				  puts last_response.body
				  
				  last_response.should be_ok
				  
				  actual = JSON.parse(last_response.body)
				  expected = person_hash

				  actual.should have_key('created_at')
				  actual.should have_key('updated_at')
				  expected.keys.each { |k| actual.should have_key(k) }
				  actual.values.each { |v| v.should_not eq(nil) }
				  #actual.should include(expected)
    }
  end
  
  it "accepts a new hometeaching snapshot" do
    assign_json = IO.read("snapshot.json")
    assign_hash = JSON.parse assign_json
    
    post '/api/snapshots', assign_json
    
    last_response.should be_ok
    
    actual = JSON.parse(last_response.body)
    expected = assign_hash

    actual.should have_key('created_at')
    actual.should have_key('updated_at')
    
    actual.should include(expected)
    #expected.keys.each { |k| actual.should have_key(k) }
    #actual.values.each { |v| v.should_not eq(nil) }
  end
  
  it "can add an assignment to a snapshot" do
    assign_json = IO.read("assignment.json")
    assign_hash = JSON.parse assign_json
    
    post "/api/snapshots/#{assign_hash['group_id']}/assigments", assign_json
    
    last_response.should be_ok
    
    #actual = JSON.parse(last_response.body)
    #actual.should have_key('created_at')
    #actual.should have_key('updated_at')
    expected = assign_hash
     
     
    puts "add assignment to snapshot" 
    puts last_response.body
    
    #actual.should include(expected)
    #expected.keys.each { |k| actual.should have_key(k) }
    #actual.values.each { |v| v.should_not eq(nil) }
  end  
  
  it "can update an assignment" do
    
    assign_json = IO.read("assignment_updated.json")
    assign_hash = JSON.parse assign_json
    
    put "/api/assignments/#{assign_hash['id']}", assign_json
    
    last_response.should be_ok
    
    expected = assign_hash
    #actual = JSON.parse(last_response.body)

    puts last_response.body
    
    #actual.should include(expected)
    #expected.keys.each { |k| actual[k].should eq(expected[k]) }
  end
  
  it "can delete an assignment" do
    
    assign_json = IO.read("assignment_updated.json")
    assign_hash = JSON.parse assign_json
    
    delete "/api/assignments/#{assign_hash['id']}", assign_json
    
    last_response.should be_ok
    
    #expected = assign_hash
    #actual = JSON.parse(last_response.body)

    puts last_response.body
    
    #actual.should include(expected)
    #expected.keys.each { |k| actual[k].should eq(expected[k]) }
  end
end
