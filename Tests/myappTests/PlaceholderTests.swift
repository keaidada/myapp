import Testing
@testable import myapp

struct PlaceholderTests {
    @Test func substitutesVariables() {
        let result = Placeholder.substitute("docker run -p {port}:80 {image}", values: ["port": "8080", "image": "nginx"])
        #expect(result == "docker run -p 8080:80 nginx")
    }

    @Test func leavesUnknownPlaceholders() {
        let result = Placeholder.substitute("echo {name}", values: [:])
        #expect(result == "echo {name}")
    }

    @Test func emptyValuesReplace() {
        let result = Placeholder.substitute("echo {a}-{b}", values: ["a": "", "b": "x"])
        #expect(result == "echo -x")
    }
}
