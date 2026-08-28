# ---------- build ----------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Dependencies resolve in their own layer, so a source-only change does not
# re-download the world on every deploy.
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q clean package -DskipTests

# ---------- run ----------
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Never run as root.
RUN addgroup -S app && adduser -S app -G app

COPY --from=build /app/target/*.jar app.jar
USER app

# The app's local default port (8097) avoids a clash on the dev machine; inside a
# container 8080 is the convention. Render overrides PORT anyway.
ENV PORT=8080
EXPOSE 8080

# Tuned for the shape of a free Render instance: 512 MB of RAM, a fraction of a CPU,
# and frequent cold starts. Startup time matters far more here than peak throughput,
# because the API spends its life waiting on Postgres rather than burning CPU.
#
#   MaxRAMPercentage   keeps the heap inside the container; the JVM otherwise sizes
#                      itself against the host and gets OOM-killed.
#   UseSerialGC        G1's concurrent collector threads cost more than they return on
#                      a fraction of a CPU with a small heap. Serial starts quicker and
#                      leaves more of that fraction for the application.
#   TieredStopAtLevel=1 compile with C1 only. Reaches usable speed much sooner, at the
#                      cost of peak throughput this workload never reaches anyway.
#   Xss512k            Tomcat's thread pool at the default 1 MB stack each is real money
#                      when the whole container has 512 MB.
ENTRYPOINT ["java", \
            "-XX:MaxRAMPercentage=75", \
            "-XX:+UseSerialGC", \
            "-XX:TieredStopAtLevel=1", \
            "-Xss512k", \
            "-jar", "app.jar"]
