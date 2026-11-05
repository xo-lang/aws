# Real AWS tests

Everything else in this repository runs offline. These tests are the
exception: `integration/realaws`, run by `scripts/integration-aws.sh`,
checks the SDK against AWS itself. They run only when someone with an
AWS account starts them on purpose, and they clean up after themselves.

## Modes

| Command | What it does |
|---|---|
| `scripts/integration-aws.sh` | dry run: lists the steps and runs the offline tests of the guards and the sweep; no network |
| `scripts/integration-aws.sh --emulator` | every step LocalStack supports, against LocalStack in Docker, then checks that the sweep removes deliberate leftovers |
| `XO_AWS_REAL=1 XO_AWS_EXPECT_ACCOUNT=<12 digits> scripts/integration-aws.sh` | against AWS, with the default credentials chain of the shell |
| `XO_AWS_REAL=1 XO_AWS_EXPECT_ACCOUNT=... scripts/integration-aws.sh --sweep [--delete]` | lists (and deletes) leftovers of any run |

`XO_AWS_STEPS` picks steps (`1,8` or `3,12,13`). Without it the core
steps run, and the optional ones (3, 12, 13) run only when listed.

## Guards

- Nothing is created unless STS GetCallerIdentity names the account in
  `XO_AWS_EXPECT_ACCOUNT`; a mismatch stops the run and shows only the
  last four digits of the account found.
- The regions are set by the script (ca-central-1, and eu-north-1 for
  the multi-region step; `XO_AWS_REAL_REGION` and `XO_AWS_REAL_REGION2`
  override them), never taken from the profile, and us-east-1 is refused.
- Configured endpoint URLs (`AWS_ENDPOINT_URL...`) are ignored in a real
  run.
- Every resource is named `xo-lang-aws-it-<8 hex>-<step>`. Each step
  deletes what it made, even when it fails; the script's EXIT trap then
  sweeps the run's prefix. The sweep checks every name against the prefix
  itself, not only through the service's filter.
- Account IDs are scrubbed from cleanup errors.

## Steps

| # | Service and operations | Mode |
|---|---|---|
| 1 | STS GetCallerIdentity, header signed and presigned | both |
| 2 | S3: objects, CopyObject, ListObjectsV2 paginator, multipart, presigned PUT and GET, a tampered presign refused, NoSuchKey and NotFound, bucket waiters | both |
| 3 | S3 SelectObjectContent (optional; skipped where the account has no S3 Select) | real |
| 4 | DynamoDB: table waiters, items, Scan paginator, ResourceNotFound | both |
| 5 | SQS: send, receive, delete | both |
| 6 | SNS: topic, publish | both |
| 7 | Secrets Manager: create, read, force delete | both |
| 8 | EC2: DescribeRegions, DescribeAvailabilityZones, DescribeInstances | both |
| 9 | Kinesis: SubscribeToShard over an enhanced fan-out consumer | both |
| 10, 11 | Polly SynthesizeSpeech into Transcribe Streaming StartStreamTranscription | real |
| 12 | Lambda InvokeWithResponseStream (optional; creates one IAM role) | real |
| 13 | SigV4a through an S3 Multi-Region Access Point (optional; up to an hour to create) | real |

A full run costs well under $0.25 at list prices.

## Permissions

`docs/real-aws-policy.json` is an IAM policy limited to the
`xo-lang-aws-it-*` resources (replace `<ACCOUNT_ID>`). The only IAM
change a run makes is step 12's role: trusted by Lambda alone, with only
the AWSLambdaBasicExecutionRole managed policy, removed by the step and
by the sweep.
