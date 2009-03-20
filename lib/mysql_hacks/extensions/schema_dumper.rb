class ActiveRecord::SchemaDumper
  def indexes(table, stream)      
    if (indexes = @connection.indexes(table)).any?
      add_index_statements = indexes.map do |index|
        if (index.name.match(/^fulltext_/) and @connection.is_a?(ActiveRecord::ConnectionAdapters::MysqlAdapter))
          statment_parts = [ ('add_fulltext_index ' + index.table.inspect) ]
        else
          statment_parts = [ ('add_index ' + index.table.inspect) ]
        end
        statment_parts << index.columns.inspect
        statment_parts << (':name => ' + index.name.inspect)
        statment_parts << ':unique => true' if index.unique

        '  ' + statment_parts.join(', ')
      end

      stream.puts add_index_statements.sort.join("\n")
      stream.puts
    end
  end

  def tables(stream)
    tables = [ ]
    views = [ ]

    @connection.tables.sort.each do |table_name|
      next if ["schema_info", ignore_tables].flatten.any? do |ignored|
        case ignored
        when String; table_name == ignored
        when Regexp; table_name =~ ignored
        else
          raise StandardError, 'ActiveRecord::SchemaDumper.ignore_tables accepts an array of String and / or Regexp values.'
        end
      end 

      case (@connection.table_type(table_name))
      when :table:
        tables << table_name
      when :view:
        views << table_name
      end
    end

    tables.each do |table_name|
      table(table_name, stream)
    end

    views.each do |view_name|
      view(view_name, stream)
    end
  end
  
  def table(table, stream)
    columns = @connection.columns(table)
    begin
      tbl = StringIO.new

      if @connection.respond_to?(:pk_and_sequence_for)
        pk, pk_seq = @connection.pk_and_sequence_for(table)
      end
      pk ||= 'id'

      tbl.print "  create_table #{table.inspect}"
      if columns.detect { |c| c.name == pk }
        if pk != 'id'
          tbl.print %Q(, :primary_key => "#{pk}")
        end
      else
        tbl.print ", :id => false"
      end
      tbl.print ", :options => '#{@connection.table_options(table)}'"
      tbl.print ", :force => true"
      tbl.puts " do |t|"

      column_specs = columns.map do |column|
        raise StandardError, "Unknown type '#{column.sql_type}' for column '#{column.name}'" if @types[column.type].nil?
        next if column.name == pk
        spec = {}
        spec[:name]      = column.name.inspect
        spec[:type]      = column.type.to_s
        spec[:limit]     = column.limit.inspect if column.limit != @types[column.type][:limit] && column.type != :decimal
        spec[:precision] = column.precision.inspect if !column.precision.nil?
        spec[:scale]     = column.scale.inspect if !column.scale.nil?
        spec[:null]      = 'false' if !column.null
        spec[:default]   = default_string(column.default) if column.has_default?
        (spec.keys - [:name, :type]).each{ |k| spec[k].insert(0, "#{k.inspect} => ")}
        spec
      end.compact

      # find all migration keys used in this table
      keys = [:name, :limit, :precision, :scale, :default, :null] & column_specs.map(&:keys).flatten

      # figure out the lengths for each column based on above keys
      lengths = keys.map{ |key| column_specs.map{ |spec| spec[key] ? spec[key].length + 2 : 0 }.max }

      # the string we're going to sprintf our values against, with standardized column widths
      format_string = lengths.map{ |len| "%-#{len}s" }

      # find the max length for the 'type' column, which is special
      type_length = column_specs.map{ |column| column[:type].length }.max

      # add column type definition to our format string
      format_string.unshift "    t.%-#{type_length}s "

      format_string *= ''

      column_specs.each do |colspec|
        values = keys.zip(lengths).map{ |key, len| colspec.key?(key) ? colspec[key] + ", " : " " * len }
        values.unshift colspec[:type]
        tbl.print((format_string % values).gsub(/,\s*$/, ''))
        tbl.puts
      end

      tbl.puts "  end"
      tbl.puts
      
      indexes(table, tbl)

      tbl.rewind
      stream.print tbl.read
    rescue => e
      stream.puts "# Could not dump table #{table.inspect} because of following #{e.class}"
      stream.puts "#   #{e.message}"
      stream.puts
    end
    
    stream
  end

  def view(table, stream)
    begin
      tbl = StringIO.new

      definition = @connection.table_definition(table)

      definition.gsub!(/ DEFINER=\S+/, '')
      definition.gsub!(/ SQL SECURITY DEFINER/, '')

      tbl.puts "  execute(\n    \"#{definition.gsub(/\"/, '\\\"')}\"\n  )\n"

      tbl.rewind
      stream.print tbl.read
    rescue => e
      stream.puts "# Could not dump table #{table.inspect} because of following #{e.class}"
      stream.puts "#   #{e.message}"
      stream.puts
    end

    stream
  end
end
