require 'spec_helper'

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
      expect(HTTParty::HashConversions.to_params(hash)).to eq("name=bob&address%5Bstreet%5D=111%20ruby%20ave.&address%5Bcity%5D=ruby%20central&address%5Bphones%5D%5B%5D=111-111-1111&address%5Bphones%5D%5B%5D=222-222-2222")
    end

    context "nested params" do
      it 'creates a params string from a hash' do
        hash = { marketing_event: { marketed_resources: [ {type:"product", id: 57474842640 } ] } }
        expect(HTTParty::HashConversions.to_params(hash)).to eq("marketing_event%5Bmarketed_resources%5D%5B%5D%5Btype%5D=product&marketing_event%5Bmarketed_resources%5D%5B%5D%5Bid%5D=57474842640")
      end
    end
  end

  describe ".normalize_keys" do
    def pairs(hash)
      hash.flat_map { |key, value| HTTParty::HashConversions.normalize_keys(key, value) }
    end

    it "returns one [key, value] pair per field for an array of hashes with several keys" do
      expect(pairs(user: { pets: [{ name: "a", age: 1 }, { name: "b", age: 2 }] })).to eq([
        ["user[pets][][name]", "a"], ["user[pets][][age]", 1],
        ["user[pets][][name]", "b"], ["user[pets][][age]", 2]
      ])
    end

    it "returns one [key, value] pair per value for an array of arrays" do
      expect(pairs(m: { grid: [[1, 2], [3]] })).to eq([["m[grid][][]", 1], ["m[grid][][]", 2], ["m[grid][][]", 3]])
    end

    it "keeps sibling fields before nested hash fields, as before" do
      expect(pairs(user: { address: { city: "x" }, name: "n" })).to eq([["user[name]", "n"], ["user[address][city]", "x"]])
    end

    it "still leaves out an empty nested array" do
      expect(pairs(user: { tags: [], name: "n" })).to eq([["user[name]", "n"]])
    end
  end

  describe ".normalize_param" do
    context "value is an array" do
      it "creates a params string" do
        expect(
          HTTParty::HashConversions.normalize_param(:people, ["Bob Jones", "Mike Smith"])
        ).to eq("people%5B%5D=Bob%20Jones&people%5B%5D=Mike%20Smith&")
      end
    end

    context "value is an empty array" do
      it "creates a params string" do
        expect(
          HTTParty::HashConversions.normalize_param(:people, [])
        ).to eq("people%5B%5D=&")
      end
    end

    context "value is hash" do
      it "creates a params string" do
        expect(
          HTTParty::HashConversions.normalize_param(:person, { name: "Bob Jones" })
        ).to eq("person%5Bname%5D=Bob%20Jones&")
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
