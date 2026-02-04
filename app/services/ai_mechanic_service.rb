require 'net/http'
require 'json'
require 'uri'

class AiMechanicService
  # CONFIGURACIÓN: GOOGLE GEMINI NATIVO
  # Usamos el alias '-latest' que suele ser el más compatible para evitar el error 404
  MODEL_NAME = "gemini-1.5-flash-latest" 
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/#{MODEL_NAME}:generateContent"

  def ask(user_question, chat_history = [])
    # 1. Detector de intención
    intent = detect_intent(user_question, chat_history)

    if intent == 'CHAT'
      return simple_chat(user_question, chat_history)
    else
      return handle_data_query(user_question, chat_history)
    end
  end

  private

  # --- CEREBRO: DETECTOR DE INTENCIÓN ---
  def detect_intent(question, history)
    system_prompt = "Eres un clasificador. Si el usuario pide datos de coches/DB -> Responde 'SQL'. Si saluda o charla -> Responde 'CHAT'. Responde SOLO con una palabra."
    
    # En detector usamos temperatura 0 para precisión
    response = call_google_native(system_prompt, question, [], temperature: 0.0)
    
    return 'CHAT' if response.nil?
    response.to_s.upcase.include?('SQL') ? 'SQL' : 'CHAT'
  end

  # --- MODO CHARLA ---
  def simple_chat(question, history)
    system_prompt = "Eres 'Fleet Scraper', un asistente experto en coches. Sé breve, simpático y usa emojis."
    call_google_native(system_prompt, question, history, temperature: 0.7)
  end

  # --- MODO DATOS (SQL) ---
  def handle_data_query(question, history)
    sql_query = generate_sql(question, history)
    return "❌ No entendí qué buscar exactamente." unless sql_query

    results = execute_safe_sql(sql_query)
    
    if results[:error]
      return "⚠️ Error técnico en SQL: #{results[:error]}"
    end

    if results[:data].empty?
      return "🕵️ Busqué en la base de datos, pero no encontré ningún coche así."
    end

    explain_results(question, results[:data], history)
  end

  def generate_sql(question, history)
    schema = <<~TEXT
      Eres un experto en SQL PostgreSQL.
      ESQUEMA DB:
      - brands (id, name)
      - models (id, name, brand_id)
      - vehicles (id, model_id, name, production_start_year, body_type, trunk_max_l)
      - engine_specs (vehicle_id, horsepower_ps, fuel_type, cylinders, electric_range_km)
      - performance_stats (vehicle_id, top_speed_kmh, acceleration_0_100, fuel_consumption_wltp)
      
      REGLAS:
      1. Genera SOLO el código SQL. Sin markdown, sin explicaciones.
      2. Usa ILIKE para búsquedas de texto.
      3. Haz JOINs explícitos.
    TEXT

    prompt = "Pregunta: \"#{question}\". SQL:"
    response = call_google_native(schema, prompt, history, temperature: 0.0)
    clean_sql(response)
  end

  def explain_results(question, data, history)
    data_preview = data.first(8).map { |row| row.values.join(" | ") }.join("\n")
    system_prompt = "Eres un experto en coches. Tienes estos datos de la DB. Explícaselos al usuario de forma natural y útil."
    prompt = "Pregunta: \"#{question}\". Datos: \n#{data_preview}. Respuesta:"
    
    call_google_native(system_prompt, prompt, history, temperature: 0.7)
  end

  # --- CONEXIÓN A GOOGLE NATIVO ---
  def call_google_native(system_instruction, current_prompt, history, temperature: 0.5)
    # AÑADIDO: .strip para evitar errores si copiaste la clave con un espacio al final
    api_key = ENV['GEMINI_API_KEY']&.strip
    
    if api_key.nil? || api_key.empty?
      puts "🚨 ERROR: Falta GEMINI_API_KEY en .env"
      return nil
    end

    uri = URI("#{API_URL}?key=#{api_key}")
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    
    # 1. Historial
    contents = history.map do |entry|
      role = entry[:role] == 'user' ? 'user' : 'model'
      { role: role, parts: [{ text: entry[:content] }] }
    end

    # 2. Prompt actual
    contents << { role: 'user', parts: [{ text: current_prompt }] }

    # 3. Payload
    payload = {
      contents: contents,
      systemInstruction: { parts: [{ text: system_instruction }] },
      generationConfig: {
        temperature: temperature,
        maxOutputTokens: 1000
      }
    }
    
    request.body = payload.to_json

    begin
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
      
      if response.code.to_i >= 400
        puts "🚨 GOOGLE API ERROR (#{response.code}): #{response.body}"
        # Si falla el 'latest', intentamos sugerir al usuario qué hacer
        if response.code.to_i == 404
           puts "👉 CONSEJO: El modelo '#{MODEL_NAME}' no se encuentra. Intenta cambiar en el archivo a 'gemini-1.5-flash-001'"
        end
        return nil
      end

      json = JSON.parse(response.body)
      
      # Extracción segura
      return json.dig('candidates', 0, 'content', 'parts', 0, 'text')

    rescue => e
      puts "🚨 NETWORK ERROR: #{e.message}"
      return nil
    end
  end

  # --- UTILIDADES ---
  def clean_sql(text)
    return nil if text.nil?

    if text.include?('```')
      match = text.match(/```(?:sql)?(.*?)```/m)
      return match[1].strip if match
    end

    match = text.match(/(SELECT.*?;)/im)
    return match[1].strip if match

    cleaned = text.strip
    return cleaned if cleaned.upcase.start_with?('SELECT')
    
    nil
  end

  def execute_safe_sql(sql)
    if sql.match?(/\b(DROP|DELETE|UPDATE|INSERT|ALTER|TRUNCATE|GRANT)\b/i)
      return { error: "Modificación bloqueada por seguridad." }
    end

    begin
      result = AiReadonlyRecord.connection.execute(sql)
      { data: result.to_a, error: nil }
    rescue => e
      { data: [], error: e.message }
    end
  end

  def history_to_messages(history)
    history
  end
end