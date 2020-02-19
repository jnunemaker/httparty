Feature: Handles Compressed Responses

  In order to save bandwidth
  As a developer
  I want to leverage Net::Http's built in transparent support for gzip and deflate content encoding

  Scenario: Supports deflate encoding
    Given a remote deflate service
    And the response from the service has a body of '<h1>Some HTML</h1>'
    And that service is accessed at the path '/deflate_service.html'
    When I call HTTParty#get with '/deflate_service.html'
    Then the return value should match '<h1>Some HTML</h1>'
    And it should return a response without a content-encoding

  Scenario: Supports gzip encoding
    Given a remote gzip service
    And the response from the service has a body of '<h1>Some HTML</h1>'
    And that service is accessed at the path '/gzip_service.html'
    When I call HTTParty#get with '/gzip_service.html'
    Then the return value should match '<h1>Some HTML</h1>'
    And it should return a response without a content-encoding

  Scenario: Supports gzip encoding with explicit header set
    Given a remote gzip service
    And the response from the service has a body of '<h1>Some HTML</h1>'
    And that service is accessed at the path '/gzip_service.html'
    When I set my HTTParty header 'User-Agent' to value 'Party'
    And I call HTTParty#get with '/gzip_service.html'
    Then the return value should match '<h1>Some HTML</h1>'
    And it should return a response without a content-encoding

  Scenario: Supports deflate encoding with explicit header set
    Given a remote deflate service
    And the response from the service has a body of '<h1>Some HTML</h1>'
    And that service is accessed at the path '/deflate_service.html'
    When I set my HTTParty header 'User-Agent' to value 'Party'
    And I call HTTParty#get with '/deflate_service.html'
    Then the return value should match '<h1>Some HTML</h1>'
    And it should return a response without a content-encoding

