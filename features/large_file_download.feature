Feature: Handles large downloads in fragments

	As a developer
	I want large downloads delivered in fragments
	So that I can immediately write fragments, conserving memory
	
	Scenario: supports reading a response in fragments
		Given a remote service that returns a large result
		And that service is accessed at the path '/large_response.html'
		When I set my HTTParty fragments option
    And I call HTTParty#get with '/large_response.html'
		Then the response should have more than one fragment for '/large_response.html'
