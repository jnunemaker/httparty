module HTTParty
  module Xml
    def self.parse(body)
      Crack::XML.parse(body)
    end
  end
  
  module Json
    def self.parse(body)
      Crack::JSON.parse(body)
    end
  end
  
  module Yaml
    def self.parse(str)
      ::YAML.load(str)
    end
  end
  
  module Html
    def self.parse(str)
      str
    end
  end
  
  module Text
    def self.parse(str)
      str
    end
  end
end