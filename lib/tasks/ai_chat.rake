namespace :ai do
  desc "Chatbot SQL Potenciado por SambaNova 405B"
  task chat: :environment do
    require 'readline'

    # Colores
    PURPLE = "\e[35m"
    CYAN = "\e[36m"
    GREEN = "\e[32m"
    RED = "\e[31m"
    BOLD = "\e[1m"
    RESET = "\e[0m"

    system("clear") || system("cls")

    puts "#{PURPLE}#{BOLD}"
    puts "╔════════════════════════════════════════════════════╗"
    puts "║     🚀  FLEET SCRAPER AI - SAMBANOVA 405B      ║"
    puts "╚════════════════════════════════════════════════════╝"
    puts "#{RESET}"
    puts " Estado: #{GREEN}● Online#{RESET}"
    puts " Cerebro: #{BOLD}Meta-Llama-3.1-405B-Instruct#{RESET} (El más listo del mundo)"
    puts " Base de Datos: #{CYAN}Supabase (Solo Lectura)#{RESET}"
    puts " ----------------------------------------------------"
    puts " Escribe 'salir' para cerrar."

    service = AiMechanicService.new
    history = []

    loop do
      # Input usuario
      input = Readline.readline("\n#{BOLD}Tú > #{RESET}", true)
      
      break if input.nil? || ['salir', 'exit', 'quit'].include?(input.strip.downcase)
      next if input.strip.empty?

      print "#{PURPLE}⚛️  Procesando con 405B...#{RESET}"
      
      start_time = Time.now
      
      # Llamada al servicio
      response = service.ask(input, history)
      
      elapsed = (Time.now - start_time).round(2)

      # Borrar linea de pensando
      print "\r" + (" " * 30) + "\r"

      puts "#{GREEN}AI (#{elapsed}s) >#{RESET} #{response}"

      # Guardar memoria (limitada a 10 turnos para mantener contexto fresco)
      history << { role: 'user', content: input }
      history << { role: 'assistant', content: response }
      
      if history.length > 10
        history.shift(2)
      end
    end
    
    puts "\n#{PURPLE}👋 Apagando la IA... ¡Hasta luego!#{RESET}"
  end
end