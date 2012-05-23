module Deface
  module Applicator
    module ClassMethods
      # applies all applicable overrides to given source
      #
      def apply(source, details, log=true, haml=false)
        overrides = find(details)

        if log && overrides.size > 0
          Rails.logger.info "\e[1;32mDeface:\e[0m #{overrides.size} overrides found for '#{details[:virtual_path]}'"
        end

        unless overrides.empty?
          if haml
            #convert haml to erb before parsing before
            source = Deface::HamlConverter.new(source).result
          end

          doc = Deface::Parser.convert(source)

          overrides.each do |override|
            if override.disabled?
              Rails.logger.info("\e[1;32mDeface:\e[0m '#{override.name}' is disabled") if log
              next
            end

            override.parsed_document = doc
            matches = override.matcher.matches(doc, log)

            if log
              Rails.logger.send(matches.size == 0 ? :error : :info, "\e[1;32mDeface:\e[0m '#{override.name}' matched #{matches.size} times with '#{override.selector}'")
            end

            matches.each {|match| override.execute_action match } unless matches.empty?
          end

          #prevents any caching by rails in development mode
          details[:updated_at] = Time.now

          source = doc.to_s

          Deface::Parser.undo_erb_markup!(source)
        end

        source
      end


        def select_endpoints(doc, start, finish)
          # targeting range of elements as end_selector is present
          #
          finish = "#{start} ~ #{finish}"
          starting    = doc.css(start).first

          ending = if starting && starting.parent
            starting.parent.css(finish).first
          else
            doc.css(finish).first
          end

          return starting, ending

        end

        # finds all elements upto closing sibling in nokgiri document
        #
        def select_range(first, last)
          first == last ? [first] : [first, *select_range(first.next, last)]
        end

        private

        def normalize_attribute_name(name)
          name = name.to_s.gsub /"|'/, ''

          if /\Adata-erb-/ =~ name
            name.gsub! /\Adata-erb-/, ''
          end

          name
        end
    end
  end
end
