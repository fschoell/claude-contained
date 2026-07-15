# Claude Contained — java flavor
# JetBrains Runtime (JBR) + HotswapAgent (always on) + JDTLS + Maven + JBang.
# Reproduces the original monolithic image's Java/Vaadin toolchain.
FROM claude-contained-base:latest

# ---- JBR pins ---------------------------------------------------------------
# Use the jbrsdk flavor (full JDK) so developer tools like javac/javap/jar are
# available; the plain "jbr" flavor is runtime-only and omits them.
ARG JBR_VERSION=25.0.1
ARG JBR_BUILD=b268.52
ARG JBR_FLAVOR=jbrsdk
ARG JBR_BASE_URL=https://cache-redirector.jetbrains.com/intellij-jbr

# ---- HotswapAgent pin (Maven Central) ---------------------------------------
ARG HOTSWAP_AGENT_VERSION=2.0.3

# ---- Eclipse JDT Language Server pin ----------------------------------------
ARG JDTLS_VERSION=1.40.0
ARG JDTLS_TIMESTAMP=202409261450

# ---- Install JetBrains Runtime ----------------------------------------------
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
      arm64)  JBR_ARCH="aarch64" ;; \
      amd64)  JBR_ARCH="x64" ;; \
      *)      echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac; \
    FILE="${JBR_FLAVOR}-${JBR_VERSION}-linux-${JBR_ARCH}-${JBR_BUILD}.tar.gz"; \
    URL="${JBR_BASE_URL}/${FILE}"; \
    echo "Downloading: $URL"; \
    mkdir -p /opt/jbr; \
    curl -fL "$URL" -o /tmp/jbr.tar.gz; \
    tar -xzf /tmp/jbr.tar.gz -C /opt/jbr --strip-components=1; \
    rm -f /tmp/jbr.tar.gz; \
    /opt/jbr/bin/java -version

ENV JAVA_HOME=/opt/jbr
ENV PATH="$JAVA_HOME/bin:$PATH"

# ---- Install HotswapAgent ---------------------------------------------------
RUN set -eux; \
    mkdir -p /opt/jbr/lib/hotswap; \
    curl -fL \
      "https://repo1.maven.org/maven2/org/hotswapagent/hotswap-agent/${HOTSWAP_AGENT_VERSION}/hotswap-agent-${HOTSWAP_AGENT_VERSION}.jar" \
      -o /opt/jbr/lib/hotswap/hotswap-agent.jar

# ---- HotswapAgent global configuration --------------------------------------
RUN cat <<'EOF' > /opt/jbr/lib/hotswap/hotswap-agent.properties
# Auto-swap classes without requiring debug mode
autoHotswap=true

# Watch for class changes in common locations
extraClasspath=target/classes

# Disable plugins that add overhead (keep Spring, Vaadin, Proxy, AnonymousClassPatch)
disabledPlugins=Hibernate,Logback,Log4j2,Weld,Deltaspike,WebObjects,WildFlyELResolver,MyFaces,OmniFaces,Mojarra,Resteasy,Jersey

# Vaadin specific: reduce browser refresh delay
vaadin.liveReloadQuietTime=500
EOF

# HotSwap always on (JBR 17/21/25) - requires G1 or Serial GC
# --add-opens flags enable deep reflection for HotswapAgent class redefinition
ENV JAVA_TOOL_OPTIONS="\
  -XX:+UseG1GC \
  -XX:+AllowEnhancedClassRedefinition \
  -XX:+ClassUnloading \
  -XX:HotswapAgent=fatjar \
  --add-opens=java.base/java.lang=ALL-UNNAMED \
  --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
  --add-opens=java.base/java.io=ALL-UNNAMED \
  --add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
  --add-opens=java.base/sun.security.action=ALL-UNNAMED \
  --add-opens=java.base/jdk.internal.loader=ALL-UNNAMED \
  --add-opens=java.desktop/java.beans=ALL-UNNAMED \
  --add-opens=java.desktop/com.sun.beans=ALL-UNNAMED \
  --add-opens=java.desktop/com.sun.beans.introspect=ALL-UNNAMED \
  --add-opens=java.desktop/com.sun.beans.util=ALL-UNNAMED \
  -Dvaadin.productionMode=false \
  -Dspring.devtools.restart.enabled=false"

# ---- Eclipse JDT Language Server (jdtls) ------------------------------------
RUN set -eux; \
    mkdir -p /opt/jdtls; \
    curl -fL \
      "https://download.eclipse.org/jdtls/milestones/${JDTLS_VERSION}/jdt-language-server-${JDTLS_VERSION}-${JDTLS_TIMESTAMP}.tar.gz" \
      -o /tmp/jdtls.tar.gz; \
    tar -xzf /tmp/jdtls.tar.gz -C /opt/jdtls; \
    rm -f /tmp/jdtls.tar.gz; \
    ln -s /opt/jdtls/bin/jdtls /usr/local/bin/jdtls

# ---- Install SDKMAN! with Maven + JBang (as dev user) ----------------------
USER dev
RUN set -eux; \
    curl -s "https://get.sdkman.io?rcupdate=false" | bash; \
    echo 'source "/home/dev/.sdkman/bin/sdkman-init.sh"' >> /home/dev/.bashrc; \
    bash -c 'source "/home/dev/.sdkman/bin/sdkman-init.sh" && sdk install maven'; \
    bash -c 'source "/home/dev/.sdkman/bin/sdkman-init.sh" && sdk install jbang'; \
    bash -c 'source "/home/dev/.sdkman/bin/sdkman-init.sh" && mvn --version'; \
    bash -c 'source "/home/dev/.sdkman/bin/sdkman-init.sh" && jbang version'; \
    echo "SDKMAN! setup complete - Maven and JBang installed"
USER root

# ---- Symlink key binaries to /usr/local/bin ---------------------------------
# Codex runs `bash -lc` which sources /etc/profile, clobbering inherited PATH.
# Symlinks ensure JBR/Maven/JBang binaries are found via the default Debian PATH.
RUN set -eux; \
    for bin in /opt/jbr/bin/*; do \
      ln -sf "$bin" "/usr/local/bin/$(basename "$bin")"; \
    done; \
    ln -sf /home/dev/.sdkman/candidates/maven/current/bin/mvn /usr/local/bin/mvn; \
    ln -sf /home/dev/.sdkman/candidates/jbang/current/bin/jbang /usr/local/bin/jbang
