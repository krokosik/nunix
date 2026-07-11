{
  services.traefik.dynamicConfigOptions.http.middlewares = {
    middlewares-authentik.forwardAuth = {
      # Change 'authentik' to 127.0.0.1 or the container's static IP
      address = "http://127.0.0.1:9000/outpost.goauthentik.io/auth/traefik";
      trustForwardHeader = true;
      maxResponseBodySize = 1048576;
      authResponseHeaders = [
        "X-authentik-username"
        "X-authentik-groups"
        "X-authentik-email"
        "X-authentik-name"
        "X-authentik-uid"
        "X-authentik-jwt"
        "X-authentik-meta-jwks"
        "X-authentik-meta-outpost"
        "X-authentik-meta-provider"
        "X-authentik-meta-app"
        "X-authentik-meta-version"
        "authorization"
      ];
    };
  };
}