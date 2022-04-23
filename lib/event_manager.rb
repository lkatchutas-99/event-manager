# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'
require 'time'
require 'pry-byebug'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_numbers?(phone_number)
  return error_number_prompt if phone_number.nil?

  phone_number.slice(0) if phone_number.start_with?('1')
  phone_number.length.eql?(10)
end

def build_phone_number(phone_number)
  "(#{phone_number[0..2]}) #{phone_number[3..5]} #{phone_number[6..9]}"
end

def time_targeting(date_and_time)
  hours = hash_frequency(date_and_time)
  most_hours = hours.select { |_k, v| v.eql?(hours.values.max) }.keys
  most_hours.map { |hour| hour > 12 ? (hour - 12).to_s << 'pm' : hour.to_s << 'am' }.join(' ')
end

def day_of_week_targeting(date_and_time)
  days_of_week = hash_frequency(date_and_time, date_of_week: true)
  days_of_week.select { |_k, v| v.eql?(days_of_week.values.max) }.keys.join("\n")
end

def hash_frequency(date_and_time, date_of_week: false)
  date_and_time.reduce(Hash.new(0)) do |hash, row|
    date = DateTime.strptime(row, '%m/%d/%Y %H:%M')
    hash[(date_of_week ? date.strftime('%A') : date.hour)] += 1
    hash
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w(legislatorUpperBody legislatorLowerBody)
    ).officials    
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def add_file(file_name, working_file)
  begin
    Dir.mkdir('output') unless Dir.exist?('output')
    filename = "output/#{file_name}"
    File.open(filename, 'w') { |file| file.puts working_file }
    puts "#{file_name} was successfully created"
  rescue
    puts "Error: #{file_name} could not be created"
  end
end

contents = CSV.open(
  'event_attendees.csv', 
  headers: true,
  header_converters: :symbol
)

form_letter = File.read('form_letter.erb')
progress_report = File.read('letter_to_boss.erb')
form_letter_template = ERB.new form_letter
progress_report_template = ERB.new progress_report

puts 'EventManager Initialized!'

date_and_time = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  phone_number = row[:homephone].scan(/\d/).join

  date_and_time.push(row[:regdate])
  
  legislators = legislators_by_zipcode(zipcode)

  form_letter = form_letter_template.result(binding)
  add_file("thanks_#{id}.html", form_letter)
end

boss_letter = progress_report_template.result(binding)
add_file('letter_to_boss.html', boss_letter)
