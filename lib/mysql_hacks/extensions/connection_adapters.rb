module ActiveRecord::ConnectionAdapters
  class AbstractAdapter
    def table_options(table_name)
      nil
    end
  end

  class MysqlAdapter
    def found_rows
      select_value("SELECT FOUND_ROWS()").to_i
    end
    
    def table_type(table_name)
      definition = select_one("SHOW CREATE TABLE `#{table_name}`")

      # 'C' in Create sorts first
      case (definition.keys.sort.first)
      when 'Create Table':
        :table
      when 'Create View':
        :view
      end
    end

    def table_definition(table_name)
      definition = select_one("SHOW CREATE TABLE `#{table_name}`")

      definition[definition.keys.sort.first]
    end

    def table_options(table_name)
      table_definition(table_name).split(/\r?\n/)[-1].sub(/^\s*\)\s*/, '').sub(/ AUTO_INCREMENT=\d+/, '')
    end
  end
  
  module SchemaStatements
    def add_fulltext_index(table_name, column_name, options = { })
      column_names = Array(column_name)

      index_type = 'FULLTEXT'
      index_name = fulltext_column_name(table_name, column_names, options)

      quoted_column_names = column_names.map { |e| quote_column_name(e) }.join(", ")
    
      execute "CREATE #{index_type} INDEX #{quote_column_name(index_name)} ON #{table_name} (#{quoted_column_names})"
    end
  
    def remove_fulltext_index(table_name, column_name, options = { })
      column_names = Array(column_name)

      index_name = fulltext_column_name(table_name, column_names, options)
      execute "DROP INDEX #{index_name} ON #{table_name}"
    end
  
    def fulltext_column_name(table_name, column_names, options)
      'fulltext_' + (options[:name] or index_name(table_name, :column => column_names))
    end
  end
end