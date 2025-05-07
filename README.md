# Geoserver

This is a build of Geoserver that is based on [the official Geoserver Docker repo](https://github.com/geoserver/docker). It provides the following additions:

- Running as a non-root user
- Builds for multiple architectures: linux/amd64 and linux/arm64/v8
- Includes the [Cloud Optimized GeoTIFF (COG)](https://docs.geoserver.org/main/en/user/community/cog/index.html) + [OpenID Connect plugin](https://docs.geoserver.org/main/en/user/community/oauth2/index.html)

## Enable OpenID Connect

Use the following steps to configure OpenID Connect:

1. Login with geoserver / admin
2. Go to "Authentication"
3. Add a new Authentication filter "oidc" of type OpenID Connect
4. Enter the name "oidc"
5. Use http://dex:6556/ as "Discovery document" and click "Discover"
6. Uncheck "Force Access Token URI HTTPS Secured Protocol" and "Force User Authorization URI HTTPS Secured Protocol"
7. Replace http://localhost:6556 with http://dex:6556 for the Access Token URI, Check Token Endpoint URL and JSON Web Key set URI
8. Set "Logout URI" to http://localhost/geoserver/
9. Set "Client ID" to geoserver
10. Set "Client Secret" to somethingsecret
11. Set "Response Mode" to query
12. Check "Send Client Secret in Token Request"
13. Set "Validation Method" to "Role service" and choose the role "Default"
14. Click "Save"
15. Add the oidc authentication filter to the web, rest and default request filters
16. Click "Save" on the authentication page again
