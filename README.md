# Geoserver

This is a build of Geoserver that is based on [the official Geoserver Docker repo](https://github.com/geoserver/docker). It provides the following additions:

- Running as a non-root user
- Builds for multiple architectures: linux/amd64 and linux/arm64/v8
- Includes the [Cloud Optimized GeoTIFF (COG)](https://docs.geoserver.org/main/en/user/community/cog/index.html) + [OpenID Connect plugin](https://docs.geoserver.org/main/en/user/community/oauth2/index.html)