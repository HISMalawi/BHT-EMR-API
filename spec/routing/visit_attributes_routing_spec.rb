require "rails_helper"

RSpec.describe VisitAttributesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/visit_attributes").to route_to("visit_attributes#index")
    end

    it "routes to #show" do
      expect(get: "/visit_attributes/1").to route_to("visit_attributes#show", id: "1")
    end


    it "routes to #create" do
      expect(post: "/visit_attributes").to route_to("visit_attributes#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/visit_attributes/1").to route_to("visit_attributes#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/visit_attributes/1").to route_to("visit_attributes#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/visit_attributes/1").to route_to("visit_attributes#destroy", id: "1")
    end
  end
end
