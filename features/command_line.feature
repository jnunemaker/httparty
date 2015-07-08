@command_line
Feature: Command Line

  As a developer
  I want to be able to harness the power of HTTParty from the command line
  Because that would make quick testing and debugging easy

  Scenario: Show help information
    When I run `httparty --help`
    Then the output should contain "-f, --format [FORMAT]"

  Scenario: Show current version
    When I run `httparty --version`
    Then the output should contain "Version:"
    And the output should not contain "You need to provide a URL"

  Scenario: Make a get request
    Given a remote deflate service on port '4001'
    And the response from the service has a body of 'GET request'
    And that service is accessed at the path '/fun'
    When I run `httparty http://0.0.0.0:4001/fun`
    Then the output should contain "GET request"

  Scenario: Make a post request
    Given a remote deflate service on port '4002'
    And the response from the service has a body of 'POST request'
    And that service is accessed at the path '/fun'
    When I run `httparty http://0.0.0.0:4002/fun --action post --data "a=1&b=2"`
    Then the output should contain "POST request"

  Scenario: Make a put request
    Given a remote deflate service on port '4003'
    And the response from the service has a body of 'PUT request'
    And that service is accessed at the path '/fun'
    When I run `httparty http://0.0.0.0:4003/fun --action put --data "a=1&b=2"`
    Then the output should contain "PUT request"

  Scenario: Make a delete request
    Given a remote deflate service on port '4004'
    And the response from the service has a body of 'DELETE request'
    And that service is accessed at the path '/fun'
    When I run `httparty http://0.0.0.0:4004/fun --action delete`
    Then the output should contain "DELETE request"

  Scenario: Set a verbose mode
    Given a remote deflate service on port '4005'
    And the response from the service has a body of 'Some request'
    And that service is accessed at the path '/fun'
    When I run `httparty http://0.0.0.0:4005/fun --verbose`
    Then the output should contain "content-length"

  Scenario: Use service with basic authentication
    Given a remote deflate service on port '4006'
    And the response from the service has a body of 'Successfull authentication'
    And that service is accessed at the path '/fun'
    And that service is protected by Basic Authentication
    And that service requires the username 'user' with the password 'pass'
    When I run `httparty http://0.0.0.0:4006/fun --user 'user:pass'`
    Then the output should contain "Successfull authentication"

  Scenario: Get response in plain format
    Given a remote deflate service on port '4007'
    And the response from the service has a body of 'Some request'
    And that service is accessed at the path '/fun'
    When I run `httparty http://0.0.0.0:4007/fun --format plain`
    Then the output should contain "Some request"

  Scenario: Get response in json format
    Given a remote deflate service on port '4008'
    Given a remote service that returns '{ "jennings": "waylon", "cash": "johnny" }'
    And that service is accessed at the path '/service.json'
    And the response from the service has a Content-Type of 'application/json'
    When I run `httparty http://0.0.0.0:4008/service.json --format json`
    Then the output should contain '"jennings": "waylon"'

  Scenario: Get response in xml format
    Given a remote deflate service on port '4009'
    Given a remote service that returns '<singer>waylon jennings</singer>'
    And that service is accessed at the path '/service.xml'
    And the response from the service has a Content-Type of 'text/xml'
    When I run `httparty http://0.0.0.0:4009/service.xml --format xml`
    Then the output should contain "<singer>"

  Scenario: Get response in csv format
    Given a remote deflate service on port '4010'
    Given a remote service that returns:
      """
      "Last Name","Name"
      "jennings","waylon"
      "cash","johnny"
      """
    And that service is accessed at the path '/service.csv'
    And the response from the service has a Content-Type of 'application/csv'
    When I run `httparty http://0.0.0.0:4010/service.csv --format csv`
    Then the output should contain '["Last Name", "Name"]'
