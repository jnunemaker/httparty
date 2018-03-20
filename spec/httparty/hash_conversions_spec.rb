RSpec.describe HTTParty::HashConversions do
  describe ".to_params" do
    it "creates a params string from a hash" do
      hash = {
        name: "bob",
        address: {
          street: '111 ruby ave.',
          city: 'ruby central',
          phones: ['111-111-1111', '222-222-2222']
        }
      }
      expect(HTTParty::HashConversions.to_params(hash)).to eq("name=bob&address[street]=111%20ruby%20ave.&address[city]=ruby%20central&address[phones][]=111-111-1111&address[phones][]=222-222-2222")
    end

    context "nested params" do
      it 'creates a params string from a hash' do
        hash = { marketing_event: { marketed_resources: [ {type:"product", id: 57474842640 } ] } }
        expect(HTTParty::HashConversions.to_params(hash)).to eq("marketing_event[marketed_resources][][type]=product&marketing_event[marketed_resources][][id]=57474842640")
      end
    end
  end

  describe ".normalize_param" do
    context "value is an array" do
      it "creates a params string" do
        expect(
          HTTParty::HashConversions.normalize_param(:people, ["Bob Jones", "Mike Smith"])
        ).to eq("people[]=Bob%20Jones&people[]=Mike%20Smith&")
      end
    end

    context "value is an empty array" do
      it "creates a params string" do
        expect(
          HTTParty::HashConversions.normalize_param(:people, [])
        ).to eq("people[]=&")
      end
    end

    context "value is hash" do
      it "creates a params string" do
        expect(
          HTTParty::HashConversions.normalize_param(:person, { name: "Bob Jones" })
        ).to eq("person[name]=Bob%20Jones&")
      end
    end

    context "value is a string" do
      it "creates a params string" do
        expect(
          HTTParty::HashConversions.normalize_param(:name, "Bob Jones")
        ).to eq("name=Bob%20Jones&")
      end
    end
  end
end
