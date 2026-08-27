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

# MaxRAMPercentage keeps the heap inside a 512 MB free-tier container; the JVM
# otherwise sizes itself against the host and gets OOM-killed.
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
