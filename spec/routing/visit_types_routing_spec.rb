require "rails_helper"

RSpec.describe VisitTypesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/visit_types").to route_to("visit_types#index")
    end

    it "routes to #show" do
      expect(get: "/visit_types/1").to route_to("visit_types#show", id: "1")
    end


    it "routes to #create" do
      expect(post: "/visit_types").to route_to("visit_types#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/visit_types/1").to route_to("visit_types#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/visit_types/1").to route_to("visit_types#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/visit_types/1").to route_to("visit_types#destroy", id: "1")
    end
  end
end
