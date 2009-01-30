require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Core Extensions" do
  
  describe Hash do
    
    describe "#to_params" do
      
      def should_be_same_params(query_string, expected)
        query_string.split(/&/).sort.should == expected.split(/&/).sort
      end
      
      it "should encode characters in URL parameters" do
        {:q => "?&\" +"}.to_params.should == "q=%3F%26%22%20%2B"
      end
      
      it "should handle multiple parameters" do
        should_be_same_params({:q1 => "p1", :q2 => "p2"}.to_params, "q1=p1&q2=p2")
      end
      
      it "should handle nested hashes like rails does" do
        should_be_same_params({ :name => "Bob",
            :address => {
              :street => '111 Ruby Ave.',
              :city => 'Ruby Central',
              :phones => ['111-111-1111', '222-222-2222']
            }
          }.to_params, "name=Bob&address[city]=Ruby%20Central&address[phones][]=111-111-1111&address[phones][]=222-222-2222&address[street]=111%20Ruby%20Ave.")
      end
    end
  end

end
