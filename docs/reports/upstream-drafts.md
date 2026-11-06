# Upstream drafts

Issues found while checking this SDK against aws-sdk-go-v2, written up
for the upstream project. None is filed yet; the Xo lead files them.

## 1. DynamoDB: a response CRC32 mismatch does not fail the call

Status: draft, not filed (2026-11-06).

**Where:** aws-sdk-go-v2 `service/dynamodb` v1.73.1,
`internal/customizations/checksum.go`, with smithy-go v1.28.8
`transport/http/middleware_close_response_body.go`.

**What happens:** the `DynamoDB:ResponseChecksumValidation` middleware
wraps the response body in `crc32ChecksumValidate`, whose `Close`
returns `response did not match expected checksum, <want>, <got>` when
the body's CRC32 differs from `X-Amz-Crc32`. The deserializer has
already read and decoded the body by then. The body is closed by
smithy-go's `closeResponseBody` middleware, which only logs a close
error (`failed to close HTTP response body, this may affect connection
reuse: ...`, at Warn) and returns the decoded output with a nil error.
So a call whose body was corrupted in transit succeeds, with the
corrupted data, and the retryer never sees the mismatch.

**Expected:** the call fails with the mismatch error (and the retryer
may retry it), as the customization's documentation implies
("DynamoDB responses can include a X-Amz-Crc32 header with the CRC32
checksum of the body").

**Reproduction** (local only: an `httptest` server and invented
credentials). The output with go1.26.1:

```
good: ok [t1]
absent: ok [t1]
empty: ok [t1]
wrong: ok [t1]
letters: err deserialization failed, unable to parse checksum header abc, strconv.ParseUint: parsing "abc": invalid syntax
too big: err deserialization failed, unable to parse checksum header 4294967296, strconv.ParseUint: parsing "4294967296": value out of range
spaced: ok [t1]
signed: err deserialization failed, unable to parse checksum header +1324975443, strconv.ParseUint: parsing "+1324975443": invalid syntax
repeated, first good: ok [t1]
repeated, first wrong: ok [t1]
empty first: ok [t1]
```

`wrong` sends `X-Amz-Crc32: 12345` with a body whose CRC32 is
1324975443, and the call succeeds.

```go
// Go's dynamodb v1.73.1 ListTables against a local fake answering each
// X-Amz-Crc32 variant (invented credentials, no AWS calls).
package main

import (
	"context"
	"fmt"
	"hash/crc32"
	"net/http"
	"net/http/httptest"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

const body = `{"TableNames":["t1"]}`

func main() {
	good := fmt.Sprint(crc32.ChecksumIEEE([]byte(body)))
	cases := [][]string{
		{"good", good},
		{"absent"},
		{"empty", ""},
		{"wrong", "12345"},
		{"letters", "abc"},
		{"too big", "4294967296"},
		{"spaced", " " + good},
		{"signed", "+" + good},
		{"repeated, first good", good, "1"},
		{"repeated, first wrong", "1", good},
		{"empty first", "", good},
	}
	for _, c := range cases {
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			for _, v := range c[1:] {
				w.Header().Add("X-Amz-Crc32", v)
			}
			w.Header().Set("Content-Type", "application/x-amz-json-1.0")
			w.Write([]byte(body))
		}))
		cl := dynamodb.New(dynamodb.Options{
			Region:           "us-west-2",
			BaseEndpoint:     aws.String(srv.URL),
			Credentials:      credentials.NewStaticCredentialsProvider("AKIDEXAMPLE", "SECRETEXAMPLE", ""),
			RetryMaxAttempts: 1,
		})
		out, err := cl.ListTables(context.Background(), &dynamodb.ListTablesInput{})
		if err != nil {
			msg := err.Error()
			if i := strings.Index(msg, "deserialization failed, "); i >= 0 {
				msg = msg[i:]
			}
			fmt.Printf("%s: err %s\n", c[0], msg)
		} else {
			fmt.Printf("%s: ok %v\n", c[0], out.TableNames)
		}
		srv.Close()
	}
}
```

**Suggested fix:** validate the checksum inside the deserialize step,
not on `Close`: read the body through the CRC32 tee in the
deserializer (or have the checksum middleware drain the body, then
compare, before it returns), and return the mismatch as a
`smithy.DeserializationError`, so it reaches the caller and the
retryer.

**This SDK:** fails the call on a mismatch, a deliberate difference
recorded in the README and decision 0003.
