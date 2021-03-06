module CurationConcerns
  module Actors
    class AssignIdentifierActor < AbstractActor
      def create(attributes)
        curation_concern.assign_id && next_actor.create(attributes)
      end
    end
  end
end
