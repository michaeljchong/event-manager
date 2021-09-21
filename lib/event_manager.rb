require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone_number(phone_number)
  number = phone_number.gsub(/\D/, '')
  if number.length == 10
    number
  elsif number.length == 11 && number[0] == '1'
    number[1..10]
  else
    'Phone number is missing'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def ad_targeting(hour_count, day_count)
  popular_hours = hour_count.filter { |_, v| v == hour_count.values.max }
  days = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
  popular_days = day_count.filter { |_, v| v == day_count.values.max }
  popular_days = popular_days.map { |k, _| days[k] }
  puts "Most people registered during the following hours: #{popular_hours.keys.sort.join(', ')}"
  puts "and on the following days: #{popular_days.sort.join(', ')}"
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

hour_count = Hash.new(0)
day_count = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  time = DateTime.strptime(row[:regdate], '%m/%d/%y %H:%M')
  hour_count[time.hour] += 1
  day_count[time.wday] += 1
end

ad_targeting(hour_count, day_count)
