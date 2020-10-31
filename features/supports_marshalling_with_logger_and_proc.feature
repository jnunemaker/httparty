Feature: Supports marshalling with request logger and/or proc parser
  In order to support caching responses
  As a developer
  I want the request to be able to be marshalled if I have set up a custom
  logger or have a proc as the response parser.

  Scenario: Marshal response with request logger
    Given a remote service that returns '{ "some": "data" }'
    And that service is accessed at the path '/somedata.json'
    When I set my HTTParty logger option
    And I call HTTParty#get with '/somedata.json'
    And I call Marshal.dump on the response
    Then it should not raise a TypeError exception

  Scenario: Marshal response with proc parser
    Given a remote service that returns '{ "some": "data" }'
    And that service is accessed at the path '/somedata.json'
    When I set my HTTParty parser option to a proc
    And I call HTTParty#get with '/somedata.json'
    And I call Marshal.dump on the response
    Then it should not raise a TypeError exception
