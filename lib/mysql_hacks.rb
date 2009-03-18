module MysqlHacks
  # ...
end

require 'mysql_hacks/extensions/base'
require 'mysql_hacks/extensions/connection_adapters'
require 'mysql_hacks/extensions/schema_dumper'

# to_sql, truthful?

class Object
  def to_sql
    "'" << to_s.gsub(/\//, "\\\\").gsub(/'/){"\\'"} << "'"
  end
end

class String
  def backquote
    '`' + self + '`'
  end
end
  
class TrueClass
  def truthful?
    self
  end
end

class FalseClass
  def truthful?
    self
  end
end

class ActiveSupport::TimeWithZone
  def to_sql
    "'" + strftime("%Y-%m-%d %k:%M:%S") + "'"
  end
end

class Date
  def to_sql
    "'" + strftime("%Y-%m-%d") + "'"
  end
end

class DateTime
  def to_sql
    "'" + strftime("%Y-%m-%d %k:%M:%S") + "'"
  end
end

class Time
  def to_sql
    "'" + strftime("%Y-%m-%d %k:%M:%S") + "'"
  end
end

class Float
  def to_sql
    self
  end
end

class Bignum
  def to_sql
    self
  end
end

class Fixnum
  def to_sql
    self
  end

  def truthful?
    !(self == 0)
  end
end

class Array
  def to_sql
    '(' + collect(&:to_sql) * ',' + ')'
  end
end

class NilClass
  def to_sql
    'NULL'
  end

  def truthful?
    false
  end
end
