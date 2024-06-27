## Rails 5.2.8.1 (July 12, 2022) ##

*   No changes.


## Rails 5.2.8 (May 09, 2022) ##

*   No changes.


## Rails 5.2.7.1 (April 26, 2022) ##

*   No changes.


## Rails 5.2.7 (March 10, 2022) ##

*   Fix `ActiveStorage.supported_image_processing_methods` and
    `ActiveStorage.unsupported_image_processing_arguments` that were not being applied.

    *Rafael Mendonça França*


## Rails 5.2.6.3 (March 08, 2022) ##

*   Added image transformation validation via configurable allow-list.

    Variant now offers a configurable allow-list for
    transformation methods in addition to a configurable deny-list for arguments.

    [CVE-2022-21831]


## Rails 5.2.6.2 (February 11, 2022) ##

*   No changes.


## Rails 5.2.6.1 (February 11, 2022) ##

*   No changes.


## Rails 5.2.6 (May 05, 2021) ##

*   No changes.


## Rails 5.2.5 (March 26, 2021) ##

*   Marcel is upgraded to version 1.0.0 to avoid a dependency on GPL-licensed
    mime types data.

    *George Claghorn*

*   The Poppler PDF previewer renders a preview image using the original
    document's crop box rather than its media box, hiding print margins. This
    matches the behavior of the MuPDF previewer.

    *Vincent Robert*


## Rails 5.2.4.6 (May 05, 2021) ##

*   No changes.


## Rails 5.2.4.5 (February 10, 2021) ##

*   No changes.


## Rails 5.2.4.4 (September 09, 2020) ##

*   No changes.


## Rails 5.2.4.3 (May 18, 2020) ##

*   [CVE-2020-8162] Include Content-Length in signature for ActiveStorage direct upload


## Rails 5.2.4.2 (March 19, 2020) ##

*   No changes.


## Rails 5.2.4.1 (December 18, 2019) ##

*   No changes.


## Rails 5.2.4 (November 27, 2019) ##

*   No changes.


## Rails 5.2.3 (March 27, 2019) ##

*   No changes.


## Rails 5.2.2.1 (March 11, 2019) ##

*   No changes.


## Rails 5.2.2 (December 04, 2018) ##

*   Support multiple submit buttons in Active Storage forms.

    *Chrıs Seelus*

*   Fix `ArgumentError` when uploading to amazon s3

    *Hiroki Sanpei*

*   Add a foreign-key constraint to the `active_storage_attachments` table for blobs.

    *George Claghorn*

*   Discard `ActiveStorage::PurgeJobs` for missing blobs.

    *George Claghorn*

*   Fix uploading Tempfiles to Azure Storage.

    *George Claghorn*


## Rails 5.2.1.1 (November 27, 2018) ##

*   Prevent content type and disposition bypass in storage service URLs.

    Fix CVE-2018-16477.

    *Rosa Gutierrez*


## Rails 5.2.1 (August 07, 2018) ##

*   Fix direct upload with zero-byte files.

    *George Claghorn*

*   Exclude JSON root from `active_storage/direct_uploads#create` response.

    *Javan Makhmali*


## Rails 5.2.0 (April 09, 2018) ##

*   Allow full use of the AWS S3 SDK options for authentication. If an
    explicit AWS key pair and/or region is not provided in `storage.yml`,
    attempt to use environment variables, shared credentials, or IAM
    (instance or task) role credentials. Order of precedence is determined
    by the [AWS SDK](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html).

    *Brian Knight*

*   Remove path config option from Azure service.

    The Active Storage service for Azure Storage has an option called `path`
    that is ambiguous in meaning. It needs to be set to the primary blob
    storage endpoint but that can be determined from the blobs client anyway.

    To simplify the configuration, we've removed the `path` option and
    now get the endpoint from the blobs client instead.

    Closes #32225.

    *Andrew White*

*   Generate root-relative paths in disk service URL methods.

    Obviate the disk service's `:host` configuration option.

    *George Claghorn*

*   Add source code to published npm package.

    This allows activestorage users to depend on the javascript source code
    rather than the compiled code, which can produce smaller javascript bundles.

    *Richard Macklin*

*   Preserve display aspect ratio when extracting width and height from videos
    with rectangular samples in `ActiveStorage::Analyzer::VideoAnalyzer`.

    When a video contains a display aspect ratio, emit it in metadata as
    `:display_aspect_ratio` rather than the ambiguous `:aspect_ratio`. Compute
    its height by scaling its encoded frame width according to the DAR.

    *George Claghorn*

*   Use `after_destroy_commit` instead of `before_destroy` for purging
    attachments when a record is destroyed.

    *Hiroki Zenigami*

*   Force `:attachment` disposition for specific, configurable content types.
    This mitigates possible security issues such as XSS or phishing when
    serving them inline. A list of such content types is included by default,
    and can be configured via `content_types_to_serve_as_binary`.

    *Rosa Gutierrez*

*   Fix the gem adding the migrations files to the package.

    *Yuji Yaginuma*

*   Added to Rails.

    *DHH*
