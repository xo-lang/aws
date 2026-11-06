# 0010: Smithy float members as Float32

Status: Accepted (owner, 2026-11-06): option A. Proposed by Xo AWS 1,
recommended by the Xo lead.

Correction after approval (2026-11-06): the text the owner approved said
"A Float32 prints as its shortest form, so `1.1` shows as `1.1`". That
is wrong. Xo's `Display` of `Float32(1.1)` prints `1.100000023841858`
(the float64 shortest form of the float32 value). The writers therefore
use a float32 shortest formatter of their own, so the text sent on the
wire is still Go's `1.1`; only how Xo itself prints the value differs.
The option chosen is unchanged.

## Context

The generator maps both Smithy `float` (32 bits) and `double` (64 bits)
to Xo's `Float` (64 bits; `codegen/gen/types.xo`). aws-sdk-go-v2 keeps
`float` as Go's `float32`, so a value from the wire is rounded to the
nearest float32:

- a header: `strconv.ParseFloat(v, 32)`, one rounding of the exact text;
- a JSON body: `json.Number.Float64()`, then `float32(f64)`, two
  roundings (generated deserializers, for example
  `ptr.Float32(float32(f64))` in the restJson1 protocol tests);
- XML and query bodies: the same as JSON, from the text through
  float64.

In Xo today a `float` member holds the float64 value. For a body,
`1.1` reads as 1.1, where Go holds float32(1.1) (1.100000023841858 as a
float64). Each value Xo writes back may then differ from Go's by up to
half a float32 unit in the last place.

`protocol/rest.go_parse_float(s, 32)` (2026-11-06) is Go's
`ParseFloat(s, 32)`: Go's syntax, its errors, and a single rounding to
float32 (an exact compare at a float32 midpoint, checked on Go's
double-rounding cases). Generated header readers of `float` members
use it since this decision.

Size of the change, from the pinned models (435):

- 54 service modules have a `float` member or a list or map of floats:
  424 members and 6 collections, over 92 float shapes. The most are in
  rekognition (81), odb (30), frauddetector (26), comprehend (22) and
  sagemaker (20).
- No service model binds a `float` member to an HTTP header. Only the
  Smithy protocol test models do (restJson1 and restXml
  `InputAndOutputWithHeaders`), so the header path matters for those
  tests and for any later model.
- The 54 modules hold 1.74 million generated lines. The regeneration
  changes only the float members' field types, defaults and readers and
  writers, so the diff is a small part of that.

## Options

**A. A Smithy `float` is Xo's `Float32` (recommended by the lead).**
Every `float` member, list item and map value becomes `Float32`, and
each protocol rounds as Go's does: a header through
`go_parse_float(v, 32)`, a JSON, XML or query body through Float, then
to Float32. Writers format a Float32 as Go's do: headers, query strings and
labels as `strconv.FormatFloat(float64(f), 'f', -1, 32)`, JSON and XML
bodies as smithy-go's `encoding.EncodeFloat(f, 32)` (`'e'` below 1e-6
or from 1e21). Both take the shortest text that reads back the same
float32 (`1.1`, not `1.100000023841858`).
- For: the values, the text written and the errors are Go's.
- Note: Xo's own `Display` of a Float32 prints its 64-bit shortest form
  (`1.100000023841858`), so the core needs its own float32 shortest
  formatter for the writers (checked against Go's FormatFloat).
- Against: it is a breaking API change in 54 service modules (a field
  of type `Float` becomes `Float32`). The core needs Float32 readers and
  writers (`jsonv`, `xmlv`, query, `rest.float_text`).

**B. Keep `Float` and store the float32-rounded value from headers
only.**
- For: it is a small change, and the header path is Go's.
- Against: headers and bodies disagree for the same member type. A
  header `1.1` shows as `1.100000023841858`, a body `1.1` as `1.1`.

**C. Keep `Float` and float64 values, and take only `ParseFloat(v,
32)`'s errors for headers** (for example, `1e39` is out of range).
- For: no API change, and values stay as they are.
- Against: the values still differ from Go's. It is a partial port that
  stays different from Go.

## Decision

A, approved by the owner on 2026-11-06. Every Smithy `float` member,
list item and map value is `Float32`, and each protocol reads and writes
it as aws-sdk-go-v2 does. It is a breaking change in the 54 service
modules, listed in CHANGELOG.md. Before this, `float` header members
kept `rest.parse_float`.

## Consequences

- Version bumps: a minor version for each of the 54 service modules (a
  breaking change, allowed before 1.0 and listed in each release note),
  and a minor version for the core (the Float32 readers and writers).
- Tests: Go vectors for each protocol's float32 reading and writing,
  including the double-rounding cases where a body (two roundings) and
  a header (one) differ. Also the protocol tests' float members, and a
  regeneration check over all 435 modules.
- Users' code that does arithmetic on a float member converts
  explicitly (`Float(x)`), since Xo does not convert number types
  implicitly.
