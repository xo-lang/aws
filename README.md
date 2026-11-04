# aws: an AWS SDK for Xo

A community AWS SDK for the Xo language. Not affiliated with or endorsed by
Amazon Web Services. AWS and Amazon Web Services are trademarks of
Amazon.com, Inc. or its affiliates.

Status: design. The architecture is being decided in
[docs/decisions](docs/decisions/README.md); no service client is generated
yet.

## Plan in one paragraph

A hand written core module (`github.com/xo-lang/aws`: SigV4 signing, the
credentials chain, retries, the endpoint rules engine, the AWS protocols,
event streams, paginators and waiters) plus one generated module per
service (`github.com/xo-lang/aws/s3`, `github.com/xo-lang/aws/dynamodb`,
...), generated from AWS's published Smithy models the way aws-sdk-go-v2 is,
with an API shaped like aws-sdk-go-v2's so Go users find it familiar.

## Testing policy

Everything is tested offline: AWS's Smithy protocol compliance tests, the
SigV4 and SigV4a signing test suites, the endpoint rules tests carried in
each service model, and local emulators (MinIO, LocalStack or moto) in
Docker with invented credentials. Nothing in this repository talks to real
AWS endpoints.
