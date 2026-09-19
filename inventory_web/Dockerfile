FROM debian:bookworm-slim AS web-builder

ARG FLUTTER_REVISION=c9a6c484230f8b5e408ec57be1ef71dee1e77020

RUN apt-get update \
  && apt-get install --no-install-recommends -y ca-certificates git curl unzip xz-utils \
  && rm -rf /var/lib/apt/lists/*

RUN git clone --filter=blob:none --no-checkout https://github.com/flutter/flutter.git /opt/flutter \
  && cd /opt/flutter \
  && git checkout "$FLUTTER_REVISION"

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter config --enable-web \
  && flutter precache --web \
  && flutter pub get

COPY . .
RUN flutter build web --release --dart-define=GATEWAY_URL=/gateway

FROM nginx:1.27-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=web-builder /app/build/web /usr/share/nginx/html
EXPOSE 80
