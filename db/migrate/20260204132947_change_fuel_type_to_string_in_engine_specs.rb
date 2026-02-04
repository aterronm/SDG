namespace :import do
  desc "Scraper V11.3: String Fuel Type (Guarda el tipo de combustible como texto)"
  task start: :environment do
    require 'selenium-webdriver'
    require 'nokogiri'
    require 'logger'
    require 'thread'

    # --- 1. PREGUNTA LA MARCA ---
    print "\n🚗 \e[1;33m¿Qué marca quieres buscar? (ej: Polestar, Audi):\e[0m "
    input_brand = STDIN.gets.chomp.strip
    exit if input_brand.empty?

    # --- 2. PREGUNTA EL AÑO LÍMITE ---
    print "📅 \e[1;36m¿Traer vehículos a partir de qué año? (Dejar vacío para traer TODOS): \e[0m"
    input_year = STDIN.gets.chomp.strip
    min_year = input_year.empty? ? nil : input_year.to_i

    formatted_brand = input_brand.split.map(&:capitalize).join('-')
    
    if min_year
      puts "🎯 Objetivo: #{formatted_brand} | 📅 Filtro: Solo desde #{min_year}"
    else
      puts "🎯 Objetivo: #{formatted_brand} | 📅 Filtro: TODO EL HISTORIAL"
    end
    
    FleetScraper.new(formatted_brand, min_year).run
  end

  class FleetScraper
    BASE_URL = "https://www.ultimatespecs.com"
    WORKERS_COUNT = 4 

    def initialize(brand_name, min_year)
      @brand_name_url = brand_name
      @min_year = min_year
      @start_url = "https://www.ultimatespecs.com/car-specs/#{brand_name}"
      
      db_name = brand_name.gsub('-', ' ')
      @brand = Brand.find_or_create_by!(name: db_name)
      @queue = Queue.new
      
      @mutex = Mutex.new
      @success_count = 0
      @failure_count = 0
      @skipped_count = 0
      @processed_count = 0
      @total_detected = 0
    end

    def run
      puts "🚀 INICIANDO V11.3 - #{@brand.name.upcase}"
      
      # FASE 1: RECOLECCIÓN
      puts "📡 Fase 1: Escaneando catálogo..."
      scout_driver = create_driver
      all_links = []

      begin
        scout_driver.get(@start_url)
        sleep(2)
        if scout_driver.page_source.include?("This page isn’t working")
           puts "❌ BLOQUEO EN FASE 1 (PAGE NOT WORKING)"
           return
        end
        doc = Nokogiri::HTML(scout_driver.page_source)
        doc.css('div.somerow').each { |row| all_links.concat(extract_links_from_row(row)) }
      ensure
        scout_driver.quit
      end

      @total_detected = all_links.count
      puts "   🎯 TOTAL DETECTADOS: #{@total_detected} Vehículos"
      return if all_links.empty?

      all_links.each { |link| @queue << link }

      # FASE 2: PROCESAMIENTO
      puts "🔥 Fase 2: Procesando..."
      workers = []
      WORKERS_COUNT.times { |i| workers << Thread.new { run_worker(i + 1) } }
      workers.each(&:join)
      
      puts "\n\n📊 RESUMEN FINAL:"
      puts "   ---------------------------------------"
      puts "   🔍 Detectados: #{@total_detected}"
      puts "   ✅ Guardados:  #{@success_count}"
      puts "   ⏭️  Omitidos:   #{@skipped_count} (Por antigüedad)"
      puts "   ❌ Fallidos:   #{@failure_count}"
      puts "   ---------------------------------------"
    end

    private

    def run_worker(id)
      driver = create_driver
      while !@queue.empty?
        begin
          link_data = @queue.pop(true)
          result = process_variant(driver, link_data)
          
          @mutex.synchronize do
            @processed_count += 1
            case result
            when :success then @success_count += 1
            when :skipped then @skipped_count += 1
            else @failure_count += 1
            end

            if @processed_count % 2 == 0 || @processed_count == @total_detected
               pct = (100.0 * @processed_count / @total_detected).round(1)
               print "\r⚡ #{@brand.name}: #{@processed_count}/#{@total_detected} (#{pct}%) | ✅ #{@success_count} | ⏭️  #{@skipped_count} | ❌ #{@failure_count}   "
            end
          end
        rescue ThreadError
          break
        end
      end
    ensure
      driver.quit if driver
    end

    def process_variant(driver, data)
      retries = 0
      max_retries = 3 
      
      begin
        model = Model.find(data[:model_id])
        driver.get(data[:url])
        
        page_text = driver.find_element(:tag_name, "body").text rescue ""
        raise "Página rota" if page_text.include?("This page isn")

        doc = Nokogiri::HTML(driver.page_source)
        raw_title = extract_raw_title(doc)
        raise "Título vacío" if raw_title.nil? || raw_title.empty?
        
        saved = false
        ActiveRecord::Base.connection_pool.with_connection do
          saved = save_vehicle_data_safe(raw_title, model, doc)
        end
        return saved

      rescue => e
        if retries < max_retries
          retries += 1
          sleep(1)
          retry
        else
          return :failure
        end
      end
    end

    def save_vehicle_data_safe(raw_title, model, doc)
      variant_name = clean_variant_name(raw_title, model.name)
      return :failure if variant_name.empty?
      
      years = parse_years_from_header(doc)

      if @min_year && years[:start] && years[:start] < @min_year
        return :skipped
      end
      
      body_val = get_spec(doc, "Body :") || get_spec(doc, "Body type") 

      vehicle = Vehicle.create!(
        name: variant_name,
        model: model,
        generation: get_spec(doc, "Generation"),
        production_start_year: years[:start],
        production_end_year: years[:end],
        body_type: body_val,
        doors: extract_int(get_spec(doc, "Num. of Doors")),
        seats: extract_int(get_spec(doc, "Num. of Seats")),
        wheelbase_cm: extract_float(get_spec(doc, "Wheelbase")),
        length_cm: extract_float(get_spec(doc, "Length")),
        width_cm: extract_float(get_spec(doc, "Width")),
        height_cm: extract_float(get_spec(doc, "Height")),
        ground_clearance_cm: extract_float(get_spec(doc, "Ground clearance")),
        max_towing_weight_kg: extract_int(get_spec(doc, "Max. Towing Capacity Weight")),
        turning_circle_m: extract_float(get_spec(doc, "Turning circle"))
      )

      save_engine_spec(vehicle, doc)
      save_performance_stat(vehicle, doc)
      save_chassis_spec(vehicle, doc)

      return :success
    end

    def save_engine_spec(vehicle, doc)
      raw_cc = get_spec(doc, "Engine Displacement")
      raw_cc = get_spec(doc, "Displacement") if raw_cc.nil?
      
      EngineSpec.create!(
        vehicle: vehicle,
        engine_code: get_spec(doc, "Engine Code"),
        cylinders: get_spec(doc, "Cylinders"),
        displacement_cc: extract_int(raw_cc),
        horsepower_ps: extract_int(get_spec(doc, "Horsepower")),
        torque_nm: extract_int(get_spec(doc, "Maximum torque")),
        bore_stroke: get_spec(doc, "Bore x Stroke"),
        valves: get_spec(doc, "Number of valves"),
        fuel_system: get_spec(doc, "Fuel System")&.truncate(250),
        engine_alignment: get_spec(doc, "Engine Alignment"),
        engine_position: get_spec(doc, "Engine Position"),
        engine_configuration: get_spec(doc, "Engine type"),
        total_system_power_ps: extract_int(get_spec(doc, "Total System Power")),
        total_system_torque_nm: extract_int(get_spec(doc, "Total System Torque")),
        electric_power_ps: extract_int(get_spec(doc, "Total electric power")),
        electric_torque_nm: extract_int(get_spec(doc, "Total electric torque")),
        battery_capacity_kwh: extract_float(get_spec(doc, "Battery capacity")),
        electric_range_km: extract_int(get_spec(doc, "Range (WLTP)")), 
        charging_time: get_spec(doc, "Charging Time"),
        fast_charging_time: get_spec(doc, "Fast Charging Time"),
        
        # --- AQUÍ ESTÁ EL CAMBIO ---
        fuel_type: get_spec(doc, "Fuel type"), 
        # ---------------------------
        
        catalytic_converter: get_spec(doc, "Catalytic converter")&.include?("Y") || false,
        aspiration: get_spec(doc, "Aspiration"),
        compression_ratio: get_spec(doc, "Compression Ratio")
      )
    end

    def save_performance_stat(vehicle, doc)
      PerformanceStat.create!(
        vehicle: vehicle,
        top_speed_kmh: extract_int(get_spec(doc, "Top Speed")),
        acceleration_0_100: extract_float(get_spec(doc, "Acceleration 0 to 100")),
        fuel_consumption_wltp: extract_float(get_spec(doc, "Combined WLTP") || get_spec(doc, "Fuel Consumption - Economy - Combined")),
        co2_emissions: extract_int(get_spec(doc, "CO2 emissions")),
        weight_power_ratio: extract_float(get_spec(doc, "Weight/Power Output Ratio")),
        drag_coefficient: extract_float(get_spec(doc, "Aerodynamic drag coefficient"))
      )
    end

    def save_chassis_spec(vehicle, doc)
      ChassisSpec.create!(
        vehicle: vehicle,
        drive_wheels: get_spec(doc, "Drive wheels"),
        transmission: get_spec(doc, "Gearbox"),
        curb_weight_kg: extract_int(get_spec(doc, "Curb Weight")),
        trunk_capacity_l: extract_int(get_spec(doc, "Trunk / Boot capacity")),
        fuel_tank_capacity: extract_int(get_spec(doc, "Fuel Tank Capacity")),
        front_brakes: get_spec(doc, "Front Brakes")&.truncate(250),
        rear_brakes: get_spec(doc, "Rear Brakes")&.truncate(250),
        front_tyres: get_spec(doc, "Front Tyres")&.truncate(250),
        rear_tyres: get_spec(doc, "Rear Tyres")&.truncate(250),
        front_suspension: get_spec(doc, "Front Suspension")&.truncate(250),
        rear_suspension: get_spec(doc, "Rear Suspension")&.truncate(250)
      )
    end

    def get_spec(doc, label)
      label_td = doc.css('td').find { |td| td.text.strip.downcase.include?(label.downcase) }
      return nil unless label_td
      value_td = label_td.xpath('following-sibling::td').first
      return nil unless value_td
      clean_text(value_td.text)
    end

    def clean_variant_name(full_title, model_name)
      clean = full_title.gsub(/Car Specs/i, "").gsub(/Specs/i, "")
      clean = clean.gsub(/#{@brand.name}/i, "")
      clean = clean.gsub(/#{Regexp.escape(model_name)}/i, "")
      return "" if clean.include?("This page isn")
      clean.strip.gsub(/^[\s\-\.]+/, "").strip
    end

    def extract_links_from_row(row)
      title_node = row.at_css('a.someTitle')
      return [] unless title_node
      raw_name = clean_text(title_node.text)
      model_name = raw_name.gsub(/Specs/i, "").gsub(/#{@brand.name}/i, "").strip
      variants_container = row.at_css('div.someOtherRow')
      return [] unless variants_container
      
      model = nil
      ActiveRecord::Base.connection_pool.with_connection do
        model = Model.find_or_create_by!(name: model_name, brand: @brand)
      end

      variants_container.css('a').map do |a|
        if valid_link?(a)
          { url: "#{BASE_URL}#{a['href']}", model_id: model.id }
        else
          nil
        end
      end.compact 
    end

    def valid_link?(a_node)
      href = a_node['href']
      return false unless href && href.include?('/car-specs/')
      return false if href.include?('View-more') || a_node.text.include?('View more') 
      true
    end

    def create_driver
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless=new')
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      options.add_argument('--disable-gpu')
      options.add_argument('--window-size=1920,1080')
      options.add_preference(:profile, managed_default_content_settings: { images: 2 })
      Selenium::WebDriver.for :chrome, options: options
    end

    def clean_text(text); return nil if text.nil? || text.strip.empty?; text.strip.gsub(/\s+/, ' '); end
    def extract_raw_title(doc); doc.at_css('h1')&.text; end
    def extract_int(text); return 0 if text.nil?; text.to_s.gsub(',', '').scan(/\d+/).first.to_i; end
    def extract_float(text); return 0.0 if text.nil?; text.to_s.gsub(',', '').scan(/[\d\.]+/).first.to_f; end
    
    def parse_years_from_header(doc)
      header_node = doc.at_css('.page_ficha_title_text b')
      return { start: nil, end: nil } unless header_node
      text = header_node.text.strip 
      matches = text.scan(/\d+/)
      matches.any? ? { start: matches[0].to_i, end: matches[1]&.to_i } : { start: nil, end: nil }
    end
  end
end