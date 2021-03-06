module CurationConcerns
  class WorkShowPresenter
    include ModelProxy
    include PresentsAttributes
    attr_accessor :solr_document, :current_ability, :request

    class_attribute :collection_presenter_class, :file_presenter_class, :work_presenter_class

    # modify this attribute to use an alternate presenter class for the collections
    self.collection_presenter_class = CollectionPresenter

    # modify this attribute to use an alternate presenter class for the files
    self.file_presenter_class = FileSetPresenter

    # modify this attribute to use an alternate presenter class for the child works
    self.work_presenter_class = self

    # @param [SolrDocument] solr_document
    # @param [Ability] current_ability
    # @param [ActionDispatch::Request] request the http request context
    def initialize(solr_document, current_ability, request = nil)
      @solr_document = solr_document
      @current_ability = current_ability
      @request = request
    end

    def page_title
      solr_document.title.first
    end

    # CurationConcern methods
    delegate :stringify_keys, :human_readable_type, :collection?, :representative_id, :to_s,
             to: :solr_document

    # Metadata Methods
    delegate :title, :date_created, :date_modified, :date_uploaded, :description,
             :creator, :contributor, :subject, :publisher, :language, :embargo_release_date,
             :lease_expiration_date, :rights, to: :solr_document

    # @return [Array<FileSetPresenter>] presenters for the orderd_members that are FileSets
    def file_set_presenters
      @file_set_presenters ||= member_presenters(ordered_ids & file_set_ids)
    end

    # @return FileSetPresenter presenter for the representative FileSets
    def representative_presenter
      return nil if representative_id.blank?
      @representative_presenter ||= member_presenters([representative_id]).first
    end

    # @return [Array<WorkShowPresenter>] presenters for the ordered_members that are not FileSets
    def work_presenters
      @work_presenters ||= member_presenters(ordered_ids - file_set_ids, work_presenter_class)
    end

    # @deprecated
    # @return [Array<FileSetPresenter>] presenters for the orderd_members that are FileSets
    def file_presenters
      Deprecation.warn WorkShowPresenter, "file_presenters is deprecated and will be removed in CurationConcerns 1.0. Use file_set_presenters or member_presenters instead."
      member_presenters
    end

    # @param [Array<String>] ids a list of ids to build presenters for
    # @param [Class] presenter_class the type of presenter to build
    # @return [Array<presenter_class>] presenters for the ordered_members (not filtered by class)
    def member_presenters(ids = ordered_ids, presenter_class = file_presenter_class)
      PresenterFactory.build_presenters(ids,
                                        presenter_class,
                                        *presenter_factory_arguments)
    end

    # @return [Array<CollectionPresenter>] presenters for the collections that this work is a member of
    def collection_presenters
      PresenterFactory.build_presenters(in_collection_ids,
                                        collection_presenter_class,
                                        *presenter_factory_arguments)
    end

    private

      def presenter_factory_arguments
        [current_ability, request]
      end

      # @return [Array<String>] ids of the collections that this work is a member of
      def in_collection_ids
        ActiveFedora::SolrService.query("{!field f=member_ids_ssim}#{id}",
                                        fl: ActiveFedora.id_field)
                                 .map { |x| x.fetch(ActiveFedora.id_field) }
      end

      # TODO: Extract this to ActiveFedora::Aggregations::ListSource
      def ordered_ids
        @ordered_ids ||= begin
                           ActiveFedora::SolrService.query("proxy_in_ssi:#{id}",
                                                           fl: "ordered_targets_ssim")
                                                    .flat_map { |x| x.fetch("ordered_targets_ssim", []) }
                         end
      end

      # These are the file sets that belong to this work, but not necessarily
      # in order.
      def file_set_ids
        @file_set_ids ||= begin
                            ActiveFedora::SolrService.query("{!field f=has_model_ssim}FileSet",
                                                            fl: ActiveFedora.id_field,
                                                            fq: "{!join from=ordered_targets_ssim to=id}id:\"#{id}/list_source\"")
                                                     .flat_map { |x| x.fetch(ActiveFedora.id_field, []) }
                          end
      end
  end
end
