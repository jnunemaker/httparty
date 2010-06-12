Feature: Handles Compressed Responses

  In order to save bandwidth
  As a developer
  I want to uncompress compressed responses

  Scenario: Supports deflate encoding
    Given a remote deflate service
    And the response from the service has a body of '<h1>Some HTML</h1>'
    And that service is accessed at the path '/service.html'
    When I call HTTParty#get with '/service.html'
    Then the return value should match '<h1>Some HTML</h1>'

  Scenario: Supports gzip encoding
    Given a remote gzip service
    And the response from the service has a body of '<h1>Some HTML</h1>'
    And that service is accessed at the path '/service.html'
    When I call HTTParty#get with '/service.html'
    Then the return value should match '<h1>Some HTML</h1>'
