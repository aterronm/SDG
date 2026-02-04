namespace :import do
    desc "Scraper V13.1: OFFICIAL ID (Usa el Nombre e ID reales de Auto-Data)"
    task autodata: :environment do
      require 'selenium-webdriver'
      require 'nokogiri'
      require 'logger'
      require 'thread'
  
      puts "\n🔧 MODO VISUAL + DEBUG ACTIVADO."
  
      # --- CHECK DB ---
      unless Vehicle.column_names.include?("modification_engine")
        puts "\n\e[1;31m⛔ ERROR DB: Falta 'modification_engine'. Ejecuta rails db:migrate\e[0m"
        exit
      end

# --- CHECK DB ---
unless Vehicle.column_names.include?("modification_engine")
    puts "\n\e[1;31m⛔ ERROR DB: Falta 'modification_engine'.\e[0m"
    exit
  end

  # --- LÓGICA HÍBRIDA (AUTOMÁTICA O MANUAL) ---
  if ENV['BRAND'].present?
    # Si le pasamos la marca por comando, NO preguntamos
    input_search = ENV['BRAND']
    puts "\n🤖 MODO AUTOMÁTICO DETECTADO. Buscando: #{input_search}"
  else
    # Si no, funcionamos como siempre (interactivo)
    print "\n🔍 \e[1;33mIntroduce la MARCA a buscar (ej: Acura, BMW, Seat):\e[0m "
    input_search = STDIN.gets.chomp.strip
  end
  
  if input_search.empty?
    puts "❌ Debes escribir algo."
    exit
  end
  
      # --- PASO 2: BUSCAR DATOS REALES ---
      puts "🌍 Buscando '#{input_search.upcase}' en el índice de marcas..."
      finder = AutoDataScraper.new(nil, nil, nil) # Iniciamos vacío para usar el buscador
      brand_data = finder.find_brand_data(input_search)
  
      if brand_data
        puts "✅ ¡Encontrada!"
        puts "   📛 Nombre Oficial: \e[1;32m#{brand_data[:name]}\e[0m"
        puts "   🔑 ID Oficial:     \e[1;36m#{brand_data[:id]}\e[0m"
        puts "   🔗 URL:            #{brand_data[:url]}"
        
        # Iniciamos el scraper con los datos OFICIALES, no lo que escribió el usuario
        AutoDataScraper.new(brand_data[:name], brand_data[:url], brand_data[:id]).run
      else
        puts "\n\e[1;31m❌ Marca no encontrada.\e[0m"
        puts "   Intenta ser más específico o revisa si existe en auto-data.net/en/allbrands"
      end
    end
  
    class AutoDataScraper
      BASE_URL = "https://www.auto-data.net"
      ALL_BRANDS_URL = "https://www.auto-data.net/en/allbrands"
      WORKERS_COUNT = 4
  
      def initialize(brand_name, start_url, brand_id)
        @brand_name = brand_name
        @start_url = start_url
        @brand_id = brand_id
        @queue = Queue.new
        @mutex = Mutex.new
        @processed = 0
        @success = 0
        @total_detected = 0
  
        # SOLO creamos/buscamos la marca si tenemos datos reales (para no romper el modo buscador)
        if @brand_id && @brand_name
          # TRUCO: Forzamos el ID al crear el registro
          # Si el ID 5 ya existe, lo coge. Si no, lo crea con ID 5.
          @brand = Brand.where(id: @brand_id).first_or_create!(name: @brand_name)
          
          # Si el nombre en la DB era diferente (ej: antes guardaste 'bmw' y ahora es 'BMW'), lo actualizamos
          if @brand.name != @brand_name
            @brand.update(name: @brand_name)
          end
        end
      end
  
      # --- MÉTODO DE BÚSQUEDA MEJORADO ---
      # Devuelve un Hash con { name: "Acura", id: 6, url: "..." }
      def find_brand_data(user_input)
        driver = create_driver(headless: true)
        driver.get(ALL_BRANDS_URL)
        doc = Nokogiri::HTML(driver.page_source)
        driver.quit
  
        target = user_input.upcase.strip
  
        # Buscamos el enlace correcto
        found_node = doc.css('a.marki_blok').find do |link|
          name_node = link.at_css('strong')
          next unless name_node
          name_node.text.strip.upcase == target
        end
  
        return nil unless found_node
        
        # EXTRAER DATOS REALES
        real_name = found_node.at_css('strong').text.strip
        href = found_node['href'] # ej: /en/acura-brand-6
        
        # Sacar el ID de la URL usando Regex (busca el número final después de '-brand-')
        # Ejemplo: "/en/acura-brand-6" -> id = 6
        id_match = href.match(/-brand-(\d+)$/)
        real_id = id_match ? id_match[1].to_i : nil
  
        return {
          name: real_name,
          id: real_id,
          url: "#{BASE_URL}#{href}"
        }
      end
      # -----------------------------------
  
      def run
        puts "🚀 INICIANDO V13.1 - #{@brand.name.upcase} (ID: #{@brand.id})"
        
        puts "📡 Fase 1: Análisis de estructura..."
        #scout = create_driver(headless: false)
        # Si estamos en el servidor (CI=true), usa headless. Si es tu PC, abre ventana.
scout = create_driver(headless: ENV['CI'] == 'true')
        
        begin
          scout.get(@start_url)
          doc = Nokogiri::HTML(scout.page_source)
          
          model_links = doc.css('a.modeli').map { |a| "#{BASE_URL}#{a['href']}" }
          puts "   📂 Modelos encontrados: #{model_links.count}"
          
          gen_links = []
          model_links.each do |m_link|
            scout.get(m_link)
            d = Nokogiri::HTML(scout.page_source)
            
            gens = d.css('table#generr a.position').map { |a| "#{BASE_URL}#{a['href']}" }
            
            if gens.empty? && d.at_css('table.carlist')
               gen_links << m_link
            else
               gen_links.concat(gens)
            end
            print "." 
          end
          puts "\n   📂 Generaciones totales: #{gen_links.count}"
  
          all_versions = []
          gen_links.each do |g_link|
            scout.get(g_link)
            d = Nokogiri::HTML(scout.page_source)
            
            versions = d.css('table.carlist tr a').select { |a| 
              a['href'].include?('/en/') && !a['href'].include?('#')
            }.map { |a| "#{BASE_URL}#{a['href']}" }
            
            all_versions.concat(versions)
          end
  
          @total_detected = all_versions.count
          puts "\n   🎯 TOTAL FICHAS A DESCARGAR: #{@total_detected}"
          
          all_versions.uniq.each { |link| @queue << link }
  
        ensure
          scout.quit
        end
  
        return if @queue.empty?
  
        puts "🔥 Fase 2: Descargando datos..."
        workers = []
        WORKERS_COUNT.times { |i| workers << Thread.new { run_worker(i + 1) } }
        workers.each(&:join)
        
        puts "\n🏁 FIN: #{@success} vehículos guardados correctamente."
      end
  
      private
  
      def run_worker(id)
        driver = create_driver(headless: ENV['CI'] == 'true')
        while !@queue.empty?
          begin
            url = @queue.pop(true)
            process_vehicle(driver, url)
            
            @mutex.synchronize do
              @processed += 1
              @success += 1
              print "\r⚡ Procesado: #{@processed}/#{@total_detected}   "
            end
          rescue ThreadError
            break
          rescue => e
             puts "\n\e[1;31m❌ ERROR GUARDANDO COCHE:\e[0m #{url}"
             puts "   MENSAJE: #{e.message}"
          end
        end
      ensure
        driver.quit
      end
  
      def process_vehicle(driver, url)
        driver.get(url)
        doc = Nokogiri::HTML(driver.page_source)
        
        data = {}
        doc.css('table.cardetailsout > tbody > tr').each do |row|
          label = row.at_css('th')&.text || row.at_css('td.left')&.text
          value = row.at_css('td.right')&.text || row.at_css('td:last-child')&.text
          next unless label && value
          data[label.gsub(':', '').strip] = value.strip
        end
  
        if data.empty?
          raise "Tabla vacía"
        end
  
        # --- LIMPIEZA DE TÍTULO ---
        raw_title = doc.at_css('h1')&.text || ""
        clean_title = raw_title
          .gsub('Technical specs, data, fuel consumption of cars', '')
          .gsub(/^Specs of\s*/i, '')
          .gsub(/\s*\/\d{4}.*$/, '')
          .strip
  
        # --- SMART NAMING ---
        model_val = data["Model"] || "Unknown"
        gen_val = data["Generation"] || ""
        
        m_down = model_val.downcase.strip
        g_down = gen_val.downcase.strip
  
        if g_down.include?(m_down)
          final_model_name = gen_val.strip
        else
          final_model_name = "#{model_val} #{gen_val}".strip
        end
  
        ActiveRecord::Base.connection_pool.with_connection do
          model = Model.find_or_create_by!(name: final_model_name, brand: @brand)
          
          start_year, end_year = parse_years(data["Start of production"], data["End of production"])
  
          # 1. VEHÍCULO
          vehicle = Vehicle.find_or_create_by!(name: clean_title, model: model) do |v|
            v.generation = gen_val
            v.production_start_year = start_year
            v.production_end_year = end_year
            v.modification_engine = data["Modification (Engine)"] 
            v.powertrain_architecture = data["Powertrain Architecture"]
            v.body_type = data["Body type"]
            v.doors = extract_int(data["Doors"])
            v.seats = extract_int(data["Seats"])
            v.length_cm = extract_float(data["Length"]) / 10.0
            v.width_cm = extract_float(data["Width"]) / 10.0
            v.width_with_mirrors_cm = extract_float(data["Width including mirrors"]) / 10.0
            v.height_cm = extract_float(data["Height"]) / 10.0
            v.wheelbase_cm = extract_float(data["Wheelbase"]) / 10.0
            v.ground_clearance_cm = extract_float(data["Ride height"] || data["Ground clearance"]) / 10.0
            v.front_track_cm = extract_float(data["Front track"]) / 10.0
            v.rear_track_cm = extract_float(data["Rear (Back) track"]) / 10.0
            v.front_overhang_cm = extract_float(data["Front overhang"]) / 10.0
            v.rear_overhang_cm = extract_float(data["Rear overhang"]) / 10.0
            v.turning_circle_m = extract_float(data["Turning circle"])
            v.max_towing_weight_kg = extract_int(data["Max. towing weight"])
            v.max_weight_kg = extract_int(data["Max. weight"])
            v.max_load_kg = extract_int(data["Max load"])
            v.trunk_capacity_max_l = extract_int(data["Trunk (boot) space - maximum"])
          end
  
          # 2. MOTOR
          unless EngineSpec.exists?(vehicle: vehicle)
            EngineSpec.create!(
              vehicle: vehicle,
              engine_code: data["Engine Model/Code"],
              cylinders: data["Cylinders"] || data["Number of cylinders"],
              displacement_cc: extract_int(data["Engine displacement"]),
              horsepower_ps: extract_int(data["Power"]),
              power_per_litre_hp_l: extract_float(data["Power per litre"]),
              torque_nm: extract_int(data["Torque"]),
              fuel_type: data["Fuel Type"],
              fuel_system: data["Fuel injection system"] || data["Fuel System"],
              engine_position: data["Engine layout"], 
              engine_configuration: data["Engine configuration"], 
              valves: data["Number of valves per cylinder"] || data["Valves per cylinder"],
              valvetrain: data["Valvetrain"], 
              bore_stroke: "#{data["Cylinder Bore"]} x #{data["Piston Stroke"]}",
              compression_ratio: data["Compression Ratio"],
              aspiration: data["Engine aspiration"], 
              oil_capacity_l: extract_float(data["Engine oil capacity"]),
              coolant_capacity_l: extract_float(data["Coolant"]),
              battery_capacity_kwh: extract_float(data["Battery capacity"]),
              electric_range_km: extract_int(data["Electric range"] || data["All-electric range"]),
              total_system_power_ps: extract_int(data["System power"]),
              total_system_torque_nm: extract_int(data["System torque"])
            )
          end
  
          # 3. PRESTACIONES
          unless PerformanceStat.exists?(vehicle: vehicle)
            PerformanceStat.create!(
              vehicle: vehicle,
              top_speed_kmh: extract_int(data["Maximum speed"]),
              acceleration_0_100: extract_float(data["Acceleration 0 - 100 km/h"]),
              acceleration_0_60_mph: extract_float(data["Acceleration 0 - 60 mph"]),
              fuel_consumption_urban: extract_float(find_val(data, "Fuel consumption", "urban")),
              fuel_consumption_extra_urban: extract_float(find_val(data, "Fuel consumption", "extra urban")),
              fuel_consumption_wltp: extract_float(find_val(data, "Fuel consumption", "combined")), 
              co2_emissions: extract_int(data["CO2 emissions"] || data["CO2 emissions (WLTP)"] || data["CO2 emissions (NEDC)"]),
              weight_power_ratio: extract_float(data["Weight-to-power ratio"]),
              drag_coefficient: extract_float(data["Drag coefficient"])
            )
          end
  
          # 4. CHASIS
          unless ChassisSpec.exists?(vehicle: vehicle)
            ChassisSpec.create!(
              vehicle: vehicle,
              drive_wheels: data["Drive wheel"],
              transmission: data["Number of gears and type of gearbox"] || data["Gearbox"],
              curb_weight_kg: extract_int(data["Kerb Weight"]),
              fuel_tank_capacity: extract_int(data["Fuel tank capacity"]),
              trunk_capacity_l: extract_int(data["Trunk (boot) space - minimum"]),
              steering_type: data["Steering type"],
              assisting_systems: data["Assisting systems"],
              front_suspension: data["Front suspension"]&.truncate(250),
              rear_suspension: data["Rear suspension"]&.truncate(250),
              front_brakes: data["Front brakes"]&.truncate(250),
              rear_brakes: data["Rear brakes"]&.truncate(250),
              front_tyres: data["Tires size"]&.truncate(250),
              rear_tyres: data["Tires size"]&.truncate(250),
              rims_size: data["Wheel rims size"]&.truncate(250)
            )
          end
        end
      end
  
      def create_driver(headless: true)
        options = Selenium::WebDriver::Chrome::Options.new
        options.add_argument('--headless=new') if headless
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-gpu')
        options.add_argument('--window-size=1920,1080')
        options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
        Selenium::WebDriver.for :chrome, options: options
      end
  
      def find_val(data, key_part1, key_part2)
        match = data.find { |k, _| k.downcase.include?(key_part1.downcase) && k.downcase.include?(key_part2.downcase) }
        match ? match[1] : nil
      end
  
      def extract_int(text); return 0 if text.nil?; text.gsub(/\s/, '').scan(/\d+/).first.to_i; end
      def extract_float(text); return 0.0 if text.nil?; text.gsub(',', '.').scan(/[\d\.]+/).first.to_f; end
      
      def parse_years(start_txt, end_txt)
        s = extract_int(start_txt)
        e = extract_int(end_txt)
        e = nil if e == 0 || end_txt&.downcase&.include?("present")
        [s, e]
      end
    end
  end