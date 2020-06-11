# frozen_string_literal: true

require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'json'
require 'yaml'
require 'geocoder'
require 'pry'

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'Numazu meibutsu GANBARUBY'
CREDENTIALS_PATH = 'credentials.json'
TOKEN_PATH = 'token.yaml'
SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY

class DataCollector
  def initialize
    @venues = {}
  end

  def add_venue(name)
    @venues[name] = true
  end

  attr_reader :venues
end

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts 'Open the following URL in the browser and enter the ' \
         "resulting code after authorization:\n" + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

def float_color_to_hex(floatcolor)
  (floatcolor * 255).round.to_s(16).rjust(2, '0')
end

def conv_color(raw_color)
  red = raw_color.red || 0
  green = raw_color.green || 0
  blue = raw_color.blue || 0
  alpha = raw_color.alpha || 1
  hex = "#{float_color_to_hex(red)}#{float_color_to_hex(green)}#{float_color_to_hex(blue)}#{float_color_to_hex(alpha)}"
end

def get_color(service, spreadsheet_id, name, cell)
  spreadsheet = service.get_spreadsheet(spreadsheet_id, include_grid_data: true, ranges: "'#{name}'!#{cell}")

  raw_color = spreadsheet.sheets[0].data[0].row_data[0].values[0].effective_format.background_color

  conv_color(raw_color)
end

def idx_to_column(num)
  alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  result = ''
  thenum = num
  loop do
    alpha_idx = thenum % 26
    result = "#{alpha[alpha_idx]}#{result}"
    thenum /= 26
    break if thenum == 0
  end
  result
end

def idx_to_row(num)
  (num + 1).to_s
end

def humanstr_to_datestring(datestr)
  month_hash = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]
               .each_with_index
               .map { |x, i| [x, i + 1] }.to_h
  month_hash['January'] = 1
  month_hash['February'] = 2
  month_hash['March'] = 3
  month_hash['April'] = 4
  month_hash['May'] = 5
  month_hash['June'] = 6
  month_hash['July'] = 7
  month_hash['August'] = 8
  month_hash['September'] = 9
  month_hash['October'] = 10
  month_hash['November'] = 11
  month_hash['December'] = 12

  date_regex = /(?<year>[0-9]{4}) (?<month>[A-Z][a-z]+) (?<day>[0-9]+)/i
  m = date_regex.match(datestr)
  month = month_hash[m[:month]].to_s.rjust(2, '0')
  day = m[:day].to_s.rjust(2, '0')
  "#{m[:year]}/#{month}/#{day}"
end

def get_sheet_data(service, spreadsheet_id, sheet_name, dc)
  types = {}
  typecolors = service.get_spreadsheet(spreadsheet_id, include_grid_data: true, ranges: "'#{sheet_name}'!B1:3")

  types[conv_color(typecolors.sheets[0].data[0].row_data[0].values[0].effective_format.background_color)] = :full
  types[conv_color(typecolors.sheets[0].data[0].row_data[1].values[0].effective_format.background_color)] = :special
  types[conv_color(typecolors.sheets[0].data[0].row_data[2].values[0].effective_format.background_color)] = :short
  types['ffff00ff'] = :special
  types['ffffffff'] = :full
  types['000000ff'] = :unreleased

  p types

  # p typecolors.sheets[0].data[0].row_data

  spreadsheet = service.get_spreadsheet(spreadsheet_id, ranges: "'#{sheet_name}'")
  result = service.get_spreadsheet_values(spreadsheet_id, "'#{sheet_name}'")

  dates = []
  songs = []

  ryears = service.get_spreadsheet_values(spreadsheet_id, "'#{sheet_name}'!D1:1").values.first
  rmonths = (service.get_spreadsheet_values(spreadsheet_id, "'#{sheet_name}'!D3:3").values || []).first || []
  rsongs = service.get_spreadsheet_values(spreadsheet_id, "'#{sheet_name}'!A7:A").values.flatten || []
  rrdates = service.get_spreadsheet_values(spreadsheet_id, "'#{sheet_name}'!B7:B").values.map { |x| x[0] }

  rtitles = (service.get_spreadsheet_values(spreadsheet_id, "'#{sheet_name}'!D4:4").values || []).first
  rinfos = (service.get_spreadsheet_values(spreadsheet_id, "'#{sheet_name}'!D5:5").values || []).first
  rvenues = (service.get_spreadsheet_values(spreadsheet_id, "'#{sheet_name}'!D6:6").values || []).first

  rdata = service.get_spreadsheet_values(spreadsheet_id, "'#{sheet_name}'!D7:#{idx_to_column(3 + rmonths.length)}#{6 + rsongs.length}").values || []

  cur_year = ''
  cur_title = ''
  cur_info = ''
  cur_venue = ''
  rmonths.each_with_index.map do |x, i|
    cur_year = ryears[i] if ryears[i] && !ryears[i].empty?
    cur_title = rtitles[i] if rtitles[i] && !rtitles[i].empty?
    cur_info = rinfos[i] if rinfos[i] && !rinfos[i].empty?
    cur_venue = rvenues[i] if rvenues[i] && !rvenues[i].empty?
    datestr = "#{cur_year} #{x}"
    dc.add_venue(cur_venue)
    dates << [humanstr_to_datestring(datestr), {
      id: i,
      title: cur_title,
      info: cur_info,
      venue: cur_venue
    }]
  end

  cur_rdate = ''
  rsongs.each_with_index.map do |x, i|
    cur_rdate = rrdates[i] if rrdates[i] && !rrdates[i].empty?
    songs << [x, {
      id: i,
      released: cur_rdate
    }]
  end

  cells = []
  rdata.each_with_index do |row, rowidx|
    row.each_with_index do |cell, columnidx|
      next if cell.to_s.empty?

      c = idx_to_column(columnidx + 3)
      r = idx_to_row(rowidx + 6)
      cells << [columnidx, rowidx, cell]
      # p get_color(service, spreadsheet_id, sheet_name, "#{c}#{r}")
    end
  end

  cmax = idx_to_column(dates.length + 3)
  rmax = idx_to_row(songs.length + 6)
  colordata = service.get_spreadsheet(spreadsheet_id, include_grid_data: true, ranges: "'#{sheet_name}'!D7:#{cmax}#{rmax}")
  datecolordata = service.get_spreadsheet(spreadsheet_id, include_grid_data: true, ranges: "'#{sheet_name}'!D3:#{cmax}3")

  dates.each_with_index do |date, idx|
    cellinfo = datecolordata.sheets[0].data[0].row_data[0].values[idx]
    next if cellinfo.nil?

    color = conv_color(cellinfo.effective_format.background_color)
    date[1][:not_performed_because] = cellinfo.note if color == '999999ff'
  end

  perf = []
  xd = {}

  cells.each do |ci, ri, cellcontent|
    color = 'ffffffff'
    unless colordata.sheets[0].data[0].row_data[ri].values[ci].nil?
      color = conv_color(colordata.sheets[0].data[0].row_data[ri].values[ci].effective_format.background_color)
    end

    # puts "#{songs[ri][0]} #{dates[ci][0]} #{cellcontent} #{color} "

    cellcontent.split('|').each do |ord|
      type = types[color]
      ord.sub!(/\(([A-Za-z]+)\)/) do |x|
        type = x.gsub(/\(|\)/, '').downcase.to_sym
        ''
      end

      perf << {
        song_id: ri,
        date_id: ci,
        order: ord.gsub(/\s+/, ''),
        type: type
      }

      # p color if types[color] == nil
    end

    xd[cellcontent] = true
  end

  # p xd.keys

  # File.write("data/", rdata.to_yaml)
  FileUtils.mkdir_p "data/perf/#{sheet_name}"
  File.write("data/perf/#{sheet_name}/songs.yml", songs.to_yaml)
  File.write("data/perf/#{sheet_name}/dates.yml", dates.to_yaml)
  File.write("data/perf/#{sheet_name}/perf.yml", perf.to_yaml)
  # puts songs.to_yaml
end

# Initialize the API
service = Google::Apis::SheetsV4::SheetsService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

dc = DataCollector.new

# Geocoder.configure(lookup: :google, api_key: )
# p Geocoder.search("Akihabara station")

spreadsheet_id = '1JI_AiobPkbYJ1J2-PLN6tq3w3Hre6lMTdYps_owxCss'
spreadsheet = service.get_spreadsheet(spreadsheet_id)

# p get_color(service, spreadsheet_id, "Aqours", "BE79")
groups = spreadsheet.sheets.each_with_index.map do |x, _i|
  result = service.get_spreadsheet_values(spreadsheet_id, "'#{x.properties.title}'!A1")
  [x.properties.title, result.values[0][0]]
end.select { |_key, first_cell| first_cell == 'Full Version' }.map { |k, _v| k }

groups.each { |group| get_sheet_data(service, spreadsheet_id, group, dc) }

FileUtils.mkdir_p 'extradata'
File.write('extradata/locs.yml', dc.venues.to_yaml)

exec('ruby geocode.rb')

# .values.map{|x| p x.length} }

# p idx_to_column(80)
