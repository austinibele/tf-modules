# static_site

This module keeps its original hosted-zone and SPA defaults for existing callers.
For a private release site in an existing zone, set `existing_zone_id`, explicitly
set `aliases`, disable `create_www_alias`, and enable `create_ipv6_alias_records`.

The secure release profile disables the S3 website endpoint, uses
`BucketOwnerEnforced` ownership and S3-managed encryption, sets
`strict_error_responses`, and enables `security_headers_policy`. It requires a
viewer-request function that maps only known directory routes to `index.html`;
unknown paths remain origin misses and return `/404.html` with status 404.
Only `releases/*` receives immutable caching in this profile; every other path
uses AWS's managed CachingDisabled policy, the no-forwarding origin-request
policy, and the security headers. The
`security_headers_content_security_policy` input keeps the restrictive default
but lets each artifact owner supply its reviewed same-origin policy.

The root module validates the certificate before supplying it to CloudFront while
the Route 53 module owns validation and aliases. Callers must pass both `aws` and
the `aws.us_east_1` provider aliases.
