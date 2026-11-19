# Mock endpoints

JSON files in this directory mock API responses so the app can run offline.
`MockURLSession` maps each request path to a file of the same name with a `.json` extension.

For example, a request to `api/auth/sign-in/email` reads `api/auth/sign-in/email.json`.

- Responses are returned with status 200 and `Content-Type: application/json`.
- Requests with no matching file get a 404 response with an empty body.
- Mocks are method-agnostic: the same file serves GET, POST, etc.
- Query strings are ignored; only the URL path is used for lookup.
