
FROM gradle:8.5-jdk21 AS builder
WORKDIR /app

COPY gradlew gradlew.bat ./
COPY gradle/ ./gradle/
COPY build.gradle.kts settings.gradle.kts versions.properties ./

RUN ./gradlew --no-daemon dependencies || true

COPY . .

RUN ./gradlew --no-daemon clean build

FROM eclipse-temurin:21-jre
WORKDIR /app

COPY --from=builder /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
