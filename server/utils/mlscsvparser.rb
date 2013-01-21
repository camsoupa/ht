require 'csv'
require 'date'
require 'rubygems'
require 'json'

class MlsCsvParser  
  attr_accessor :households, :people
  
  def initialize
    @households = []
    @people = {}
  end
  
  def parse_people csv_text
    csv_text.split("\r\n").each do |line|
      row = line.split('",').map do |field| 
        field.include?("\n") ? 
          field.split("\n").map { |subfield| subfield.delete('"').strip } : field.delete('"').strip 
      end

      id = row[17]
      names = id[id.index { |s| s.start_with? "Full Name:" }][10..-1].strip.split(/\s/)
      dob = Date.parse(id[id.index { |s| s.start_with? "Birth:" }].strip.split(/[:\(]/)[1])
      is_elder = id[id.index { |s| s.start_with? "Status:" }].include? "Elder"
      
      composite_key = person_id names.last, names.first, dob.day, dob.month
      person = @people[composite_key]
      
      person_details = { :dob     => dob,
                         :phone   => row[5].crypt('az'),
                         :email   => row[6].crypt('az'),
                         :elder   => is_elder,
                         :address => { :street  => row[7].crypt('az'), 
                                       :city    => row[8], 
                                       :state   => row[9], 
                                       :zip     => row[10],
                                       :country => row[11] } ,
                         :name    => { :first  => names.first.crypt('az'),
                                       :last   => names.last.crypt('az'),
                                       :middle => names.size > 2 ? names[1].crypt('az') : nil } }
          
      
      if !person.nil? && !person[:h_index].nil?
        household_member = @households[person[:h_index]][:people][person[:p_index]]
        person_details[:gender] = household_member[:gender]
        person_details[:family_role] = household_member[:family_role]
        @households[person[:h_index]][:people][person[:p_index]] = person_details        
      end
      
      @people[composite_key] = person_details
    end  
    
  end
  
  def person_id last, first, dob_day, dob_mo
    "#{last.crypt('az')}_#{first.crypt('az')}_#{dob_day}_#{dob_mo}"
  end
  
  def parse_households csv_text
    csv_text.split("\r\n").each do |line|
      row = line.split('",').map do |field| 
        field.include?("\n") ? 
          field.split("\n").map { |subfield| subfield.delete('"').strip } : field.delete('"').strip 
      end
      
      people = []
      people_raw = row[18].take_while { |item| !item.include? "~~~" }

      people_raw.each_slice(2) do |identity|
        person_info = identity[0]
        full_name = identity[1]
        
        family_role = :child
        if person_info.start_with? '1'
          family_role = :head
        elsif person_info.start_with? '2'
          family_role = :spouse
        end
        
        names = full_name.split(' ')
        gender = person_info.match('\((\w)\)')[1].downcase.to_sym
        dob_str = person_info.split(') ').last
        dob = Date.parse(dob_str.split(' ').size > 2 ? dob_str : dob_str + ' 1830') 
        
        #merging individual records with household records requires looking up the people,
        #so here, lacking an id, we use a composite key
        composite_key = person_id names.last, names.first, dob.day, dob.month
        person = @people[composite_key]
        
        if person.nil?
          @people[composite_key] = { :h_index => @households.size, 
                                     :p_index => people.size }
        end
        
        people.push(person != nil ? 
           person : { :dob   => dob,
                      :gender => gender,
                      :family_role => family_role,
                      :name => { :first  => names.first.crypt('az'),
                                 :last   => names.last.crypt('az'),
                                 :middle => names.size > 2 ? names[1].crypt('az') : nil } })
      end

      @households.push({ :name    => row.first.split(',').first.crypt('az'),
                         :ward    => row[3],
                         :phone   => row[5].crypt('az'),
                         :people  => people,
                         :address => { :street  => row[9].crypt('az'), 
                                       :city    => row[10], 
                                       :state   => row[11], 
                                       :zip     => row[12],
                                       :country => row[13] } })
    end
  end
end



parser = MlsCsvParser.new
parser.parse_households(IO.read('PalmFamily.csv'))
#puts JSON.generate(parser.households)

parser.parse_people(IO.read('PalmIndividual.csv'))
#puts JSON.generate(parser.people)
puts JSON.generate(parser.households)

