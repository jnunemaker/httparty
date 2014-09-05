## Examples

* [Amazon Book Search](awws.rb)
    * Httparty included into poro class
    * Uses `get` requests
    * Transforms query params to uppercased params

* [Google Search](google.rb)
  * Httparty included into poro class
  * Uses `get` requests

* [Crack Custom Parser](crack.rb)
    * Creates a custom parser for XML using crack gem
    * Uses `get` request

* [Create HTML Nokogiri parser](nokogiri_html_parser.rb)   
    * Adds Html as a format
    * passed the body of request to Nokogiri
    
* [More Custom Parser](custom_parsers.rb)
  * Create an additional parser for atom or make it the ONLY parser
  
* [Basic Auth, Delicious](delicious.rb)
  * Basic Auth, shows how to merge those into options
  * Uses `get` requests
  
* [Passing Headers, User Agent](headers_and_user_agents.rb)
  * Use the class method of Httparty
  * Pass the User-Agent in the headers
  * Uses `get` requests
  
* [Basic Post Request](basic.rb)
    * Httparty included into poro class
    * Uses `post` requests

* [Access Rubyurl Shortern](rubyurl.rb)
  * Httparty included into poro class
  * Uses `post` requests
  
* [Add a custom log file](logging.rb)
  * create a log file and have httparty log requests

* [Accessing StackExchange](stackexchange.rb)
  * Httparty included into poro class
  * Creates methods for different endpoints
  * Uses `get` requests
  
* [Accessing Tripit](tripit_sign_in.rb)
  * Httparty included into poro class
  * Example of using `debug_output` to see headers/urls passed
  * Getting and using Cookies
  * Uses `get` requests
  
* [Accessing Twitter](twitter.rb)
  * Httparty included into poro class
  * Basic Auth
  * Loads settings from a config file 
  * Uses `get` requests
  * Uses `post` requests
  
* [Accessing WhoIsMyRep](whoismyrep.rb)
  * Httparty included into poro class
  * Uses `get` requests     
  * Two ways to pass params to get, inline on the url or in query hash