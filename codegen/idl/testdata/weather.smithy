$version: "2.0"
$operationInputSuffix: "Request"

namespace example.weather

use aws.protocols#restJson1
use smithy.test#httpRequestTests

/// The service.
@restJson1
service Weather {
    version: "2006-03-01"
    operations: [GetCity, PutCity]
    errors: [NoSuchCity]
}

@readonly
@http(method: "GET", uri: "/cities/{cityId}")
operation GetCity {
    input: GetCityInput
    output: GetCityOutput
    errors: [NoSuchCity]
}

apply GetCity @httpRequestTests([
    {
        id: "GetCity"
        protocol: restJson1
        method: "GET"
        uri: "/cities/a%20b"
        body: """
            {
                "a": "b\
                c"
            }
            """
        params: { cityId: "a b", n: -1.5e3, ok: true, nothing: null }
    }
])

@http(method: "PUT", uri: "/cities")
operation PutCity {
    input := with [Named] {
        @required
        size: Integer = 0
        $name
    }
    output := {}
}

@mixin
structure Named {
    @required
    name: String
}

structure GetCityInput {
    @required
    @httpLabel
    cityId: CityId
}

structure GetCityOutput with [Named] {
    coordinates: Coords
    kind: CityKind
    level: Level
}

apply GetCityOutput$name @documentation("The city name.")

@pattern("^[A-Za-z0-9 ]+$")
string CityId

list Coords {
    member: Float
}

map Tags {
    key: String
    value: String
}

enum CityKind {
    SMALL
    LARGE = "large"
}

intEnum Level {
    LOW = 1
    HIGH = 2
}

@error("client")
structure NoSuchCity {
    message: String
}
