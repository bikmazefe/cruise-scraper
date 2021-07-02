require "byebug"
require "httparty"
require "nokogiri"

class CruiseScraper
  attr_reader :data

  def initialize(landing_url)
    @base_url = "https://www.cruisetimetables.com"
    @landing_url = landing_url
    raise "Invalid landing url" if !landing_url_valid(@landing_url)
    @data = {}
  end

  def scrape
    print_process("🛳  Reaching for Cruise Timetables...")
    response = HTTParty.get(@landing_url)
    raise "❌ Unable to reach to Cruise Timetables" if response.code != 200

    print_process("📄 Parsing landing page...")
    parsed = Nokogiri::HTML(response.body)

    years = get_years(parsed)
    collect_yearly_visits(years)

    print_process("✅ Completed")
  end

  private

  def print_process(text)
    puts ""
    puts text
    puts ""
  end

  def get_years(parsed)
    parsed.css("span.small-line-height a").map { |a| { year: a.text.gsub(/[^0-9]/, ""), link: a["href"] } }
  end

  def collect_yearly_visits(years)
    years.each do |year|
      year_name = year[:year]
      print_process("🗓  Collecting visits for #{year_name}...")
      year_url = "#{@base_url}#{year[:link]}"

      year_response = HTTParty.get(year_url)
      year_parsed = Nokogiri::HTML(year_response.body)
      raise "❌ Unable to reach to Cruise Timetables" if year_response.code != 200

      @data[year_name] = {}

      year_content = year_parsed.css("div#idContent")

      get_monthly_visits(year_content, year_name)
    end
  end

  # Use the month markers to iterate over the months_and_data array
  # and seperate the listings according to months
  def get_monthly_visits(year_content, year_name)
    # Filters the nodes within the year page to get only the month and listing nodes
    months_and_data = year_content.css("div.cdy-month, div.cdy-listing")

    # Get the indexes of months within the array to use them as "break points"
    month_indexes = get_months_with_indexes(months_and_data)

    month_indexes.entries.each_with_index do |entry, index|
      month = entry[0] # Name of the month
      month_index = entry[1] # The beginning of the month in the array (as index)
      # Check if the loop reached to the last month
      # If so, iterate until the end of the months_and_data array
      # otherwise, set the ending point to the beginning of the next month's index
      next_index = (index == month_indexes.entries.size - 1) ? months_and_data.size : month_indexes.entries[index + 1][1]

      # Start the iterator right after the month
      iterator = month_index + 1

      @data[year_name][month] = {}

      # Loop until the next month's index
      while iterator < next_index
        day = months_and_data[iterator].css("div.cdy-day a").first&.text
        ship = months_and_data[iterator].css("div.cdy-ship a").first&.text

        # If both the day and the ship is nil, it means the listing is empty.
        if !(day.nil? && ship.nil?)
          #If the day variable is nil, it means that the ship belongs to the previous day!
          if day.nil?
            previous_day = @data[year_name][month].keys.last
            @data[year_name][month][previous_day] << ship
          else
            if @data[year_name][month][day]
              @data[year_name][month][day] << ship
            else
              @data[year_name][month][day] = [ship]
            end
          end
        end
        iterator += 1
      end
    end
  end

  # Returns an object which consists of month names and their starting index within the array.
  # example: {"January" => 1, "February" => 18, ...}
  def get_months_with_indexes(months_and_data)
    obj = {}
    months_and_data.each_with_index do |item, index|
      if item.attributes["class"].value === "cdy-month"
        month = item.text.gsub(/\R+/, "")
        obj[month] = index
      end
    end
    obj
  end

  def landing_url_valid(url)
    url.match?("https://www.cruisetimetables.com/cruises-to-")
  end
end

puts "Please enter a landing url... i.e. https://www.cruisetimetables.com/cruises-to-santorini-greece.html"
landing_url = gets.chomp
scraper = CruiseScraper.new(landing_url)
scraper.scrape
puts scraper.data
