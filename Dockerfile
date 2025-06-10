FROM ubuntu:22.04 AS tomcat

ARG GEOSERVER_VERSION=2.26.3

ARG STABLE_EXTENSIONS_URL=https://build.geoserver.org/geoserver/2.26.x/ext-latest
ARG STABLE_EXTENSIONS_VERSION=2.26

ARG COMMUNITY_EXTENSIONS_URL=https://build.geoserver.org/geoserver/2.26.x/community-latest
ARG COMMUNITY_EXTENSIONS_VERSION=2.26

ARG TOMCAT_VERSION=9.0.104

ARG CORS_ENABLED=false
ARG CORS_ALLOWED_ORIGINS=*
ARG CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,HEAD,OPTIONS
ARG CORS_ALLOWED_HEADERS=*

# Environment variables
ENV CATALINA_HOME=/opt/apache-tomcat-${TOMCAT_VERSION}
ENV EXTRA_JAVA_OPTS="-Xms256m -Xmx1g"
ENV CORS_ENABLED=$CORS_ENABLED
ENV CORS_ALLOWED_ORIGINS=$CORS_ALLOWED_ORIGINS
ENV CORS_ALLOWED_METHODS=$CORS_ALLOWED_METHODS
ENV CORS_ALLOWED_HEADERS=$CORS_ALLOWED_HEADERS
ENV DEBIAN_FRONTEND=noninteractive

# see https://docs.geoserver.org/stable/en/user/production/container.html
ENV CATALINA_OPTS="\$EXTRA_JAVA_OPTS \
    -Djava.awt.headless=true -server \
    -Dfile.encoding=UTF-8 \
    -Djavax.servlet.request.encoding=UTF-8 \
    -Djavax.servlet.response.encoding=UTF-8 \
    -D-XX:SoftRefLRUPolicyMSPerMB=36000 \
    -Xbootclasspath/a:$CATALINA_HOME/lib/marlin.jar \
    -Dsun.java2d.renderer=sun.java2d.marlin.DMarlinRenderingEngine"

# init
RUN apt update \
    && apt -y upgrade \
    && apt install -y --no-install-recommends openssl unzip gdal-bin wget curl openjdk-11-jdk \
    && apt clean \
    && rm -rf /var/cache/apt/* \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/

RUN wget -q https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz \
    && tar xf apache-tomcat-${TOMCAT_VERSION}.tar.gz \
    && rm apache-tomcat-${TOMCAT_VERSION}.tar.gz \
    && rm -rf /opt/apache-tomcat-${TOMCAT_VERSION}/webapps/ROOT \
    && rm -rf /opt/apache-tomcat-${TOMCAT_VERSION}/webapps/docs \
    && rm -rf /opt/apache-tomcat-${TOMCAT_VERSION}/webapps/examples \
    && sed -i 's/<Connector/<Connector server=\" \"/g' $CATALINA_HOME/conf/server.xml \
    && sed -i '/<\/Host>/i\    <Valve className="org.apache.catalina.valves.ErrorReportValve" showServerInfo="false" />' $CATALINA_HOME/conf/server.xml

# cleanup
RUN apt purge -y  \
    && apt autoremove --purge -y \
    && rm -rf /tmp/*

FROM tomcat AS download

ARG GS_VERSION=$GEOSERVER_VERSION
ARG GS_BUILD=release
ARG WAR_ZIP_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip
ENV GEOSERVER_VERSION=$GS_VERSION
ENV GEOSERVER_BUILD=$GS_BUILD

WORKDIR /tmp

RUN echo "Downloading GeoServer ${GS_VERSION} ${GS_BUILD}" \
    && wget -q -O /tmp/geoserver.zip $WAR_ZIP_URL \
    && unzip geoserver.zip geoserver.war -d /tmp/ \
    && unzip -q /tmp/geoserver.war -d /tmp/geoserver \
    && rm /tmp/geoserver.war

FROM tomcat AS install

ARG GS_VERSION=$GEOSERVER_VERSION
ARG GS_BUILD=release

ARG COMMUNITY_EXTENSIONS_URL=$COMMUNITY_EXTENSIONS_URL
ARG COMMUNITY_EXTENSIONS_VERSION=$COMMUNITY_EXTENSIONS_VERSION

ENV GEOSERVER_VERSION=$GS_VERSION
ENV GEOSERVER_BUILD=$GS_BUILD
ENV GEOSERVER_DATA_DIR=/opt/geoserver_data/
ENV GEOSERVER_REQUIRE_FILE=$GEOSERVER_DATA_DIR/global.xml
ENV GEOSERVER_LIB_DIR=$CATALINA_HOME/webapps/geoserver/WEB-INF/lib/
ENV WAR_ZIP_URL=$WAR_ZIP_URL
ENV SKIP_DEMO_DATA=false
ENV ROOT_WEBAPP_REDIRECT=false

WORKDIR /tmp

RUN echo "Installing GeoServer $GS_VERSION $GS_BUILD"

COPY --from=download /tmp/geoserver $CATALINA_HOME/webapps/geoserver

RUN mv $CATALINA_HOME/webapps/geoserver/WEB-INF/lib/marlin-*.jar $CATALINA_HOME/lib/marlin.jar \
    && mkdir -p $GEOSERVER_DATA_DIR

# cleanup
RUN rm -rf /tmp/*

# copy scripts
COPY *.sh /opt/
RUN chmod +x /opt/*.sh

WORKDIR /opt

RUN useradd --no-create-home geoserver

RUN chown -R geoserver /opt/apache-tomcat-${TOMCAT_VERSION}

RUN mkdir -p /opt/geoserver_data && \
    chown -R geoserver /opt/geoserver_data

RUN mkdir -p /opt/additional_libs && \
    chown -R geoserver /opt/additional_libs

# SQLServer plugin (Microsoft SQL)
RUN wget --progress=bar:force:noscroll -c \
    ${STABLE_EXTENSIONS_URL}/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-sqlserver-plugin.zip \
    -O /opt/additional_libs/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-sqlserver-plugin.zip && \
    unzip -q -o -d ${GEOSERVER_LIB_DIR} /opt/additional_libs/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-sqlserver-plugin.zip "*.jar"

# Vectortiles plugin
RUN wget --progress=bar:force:noscroll -c \
    ${STABLE_EXTENSIONS_URL}/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-vectortiles-plugin.zip \
    -O /opt/additional_libs/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-vectortiles-plugin.zip && \
    unzip -q -o -d ${GEOSERVER_LIB_DIR} /opt/additional_libs/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-vectortiles-plugin.zip "*.jar"

# WPS plugin (for PointStacker)
RUN wget --progress=bar:force:noscroll -c \
    ${STABLE_EXTENSIONS_URL}/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-wps-plugin.zip \
    -O /opt/additional_libs/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-wps-plugin.zip && \
    unzip -q -o -d ${GEOSERVER_LIB_DIR} /opt/additional_libs/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-wps-plugin.zip "*.jar"

# Monitoring plugin
RUN wget --progress=bar:force:noscroll -c \
    ${STABLE_EXTENSIONS_URL}/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-monitor-plugin.zip \
    -O /opt/additional_libs/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-monitor-plugin.zip && \
    unzip -q -o -d ${GEOSERVER_LIB_DIR} /opt/additional_libs/geoserver-${STABLE_EXTENSIONS_VERSION}-SNAPSHOT-monitor-plugin.zip "*.jar"

# Commons-math3 is used by the monitoring plugin
RUN wget --progress=bar:force:noscroll -c \
    https://downloads.apache.org/commons/math/binaries/commons-math3-3.6.1-bin.zip \
    -O /opt/additional_libs/commons-math3-3.6.1-bin.zip && \
    unzip -q -o -d ${GEOSERVER_LIB_DIR} /opt/additional_libs/commons-math3-3.6.1-bin.zip "commons-math3-3.6.1/commons-math3-3.6.1.jar"

# Cloud Optimized GeoTIFF plugin
RUN wget --progress=bar:force:noscroll -c \
    ${COMMUNITY_EXTENSIONS_URL}/geoserver-${COMMUNITY_EXTENSIONS_VERSION}-SNAPSHOT-cog-http-plugin.zip \
    -O /opt/additional_libs/geoserver-${COMMUNITY_EXTENSIONS_VERSION}-SNAPSHOT-cog-http-plugin.zip && \
    unzip -q -o -d ${GEOSERVER_LIB_DIR} /opt/additional_libs/geoserver-${COMMUNITY_EXTENSIONS_VERSION}-SNAPSHOT-cog-http-plugin.zip "*.jar"

# Keycloak plugin
RUN wget --progress=bar:force:noscroll -c \
    ${COMMUNITY_EXTENSIONS_URL}/geoserver-${COMMUNITY_EXTENSIONS_VERSION}-SNAPSHOT-sec-keycloak-plugin.zip \
    -O /opt/additional_libs/geoserver-${COMMUNITY_EXTENSIONS_VERSION}-SNAPSHOT-sec-keycloak-plugin.zip && \
    unzip -q -o -d ${GEOSERVER_LIB_DIR} /opt/additional_libs/geoserver-${COMMUNITY_EXTENSIONS_VERSION}-SNAPSHOT-sec-keycloak-plugin.zip "*.jar"

# OAuth2 / OpenID Connect plugin
RUN wget --progress=bar:force:noscroll -c \
    ${COMMUNITY_EXTENSIONS_URL}/geoserver-${COMMUNITY_EXTENSIONS_VERSION}-SNAPSHOT-sec-oauth2-openid-connect-plugin.zip \
    -O /opt/additional_libs/geoserver-${COMMUNITY_EXTENSIONS_VERSION}-SNAPSHOT-sec-oauth2-openid-connect-plugin.zip && \
    unzip -q -o -d ${GEOSERVER_LIB_DIR} /opt/additional_libs/geoserver-${COMMUNITY_EXTENSIONS_VERSION}-SNAPSHOT-sec-oauth2-openid-connect-plugin.zip "*.jar"

RUN rm -Rf /opt/additional_libs

USER geoserver
EXPOSE 8080
CMD /opt/startup.sh
